---
description: 公式 CLI でマーケットプレイス・プラグインを一括最新化（公開は marketplace-publisher へ）
argument-hint: "[--dry-run] [--scope <user|project|local>]"
---

ユーザの引数: $ARGUMENTS

Claude Code 公式 CLI（`claude plugin marketplace update` / `claude plugin update`）を経由して
インストール済みマーケットプレイスとプラグインを **一括で最新版に更新** するコマンド。
**マーケットプレイス更新 → User → Project → Local の固定順** で処理し、同一プラグインが
複数スコープに存在する場合も **スコープごとに個別に更新** する。

設計判断は次の ADR を参照:
- ADR-PU-001（単一プラグイン化）/ ADR-PU-002（公式 CLI 委譲）/ ADR-PU-003（Phase 順序）/
  ADR-PU-004（横断ルール SSOT）/ ADR-PU-005（exit code 一次判定）
- 詳細: [`../references/architecture-decisions.md`](../references/architecture-decisions.md)

## 横断ルール

横断ルール **XR-1〜XR-4** の SSOT は [`../references/cross-cutting-rules.md`](../references/cross-cutting-rules.md)。
本コマンドでは各 Phase が下表のどの XR を適用するかのみを示す。規則本体は SSOT を参照のこと。

| ID | ルール | 本コマンドでの適用 Phase |
|----|------|----------------------|
| XR-1 | 入力検証 | A-1 / B / C / D / E / G-3 |
| XR-2 | タイムアウト + サーキットブレーカー | B / C / D / E / G-3 |
| XR-3 | 出力サニタイズ | F-2 / F-3 / G-2 / B-1 例外行抽出時 |
| XR-4 | リトライ上限（最大 1 回） | G-3 |

## 動作モード判定

`--scope` 指定の有無にかかわらず、**Phase B（マーケットプレイス更新）は常に実行する**。
スコープ限定はプラグイン更新（Phase C〜E）のみが対象。

| 引数 | モード | 動作 |
|-----|-------|------|
| 空 | 通常更新（全スコープ） | Phase A〜G を実行 |
| `--dry-run` | 確認のみ | 全 Phase（B/C/D/E）の実行予定 CLI を表示。実際の更新は行わない |
| `--scope user` | スコープ限定 | Phase B を **必ず実行** した後、Phase C のみ実行 |
| `--scope project` | スコープ限定 | Phase B を必ず実行した後、Phase D のみ実行 |
| `--scope local` | スコープ限定 | Phase B を必ず実行した後、Phase E のみ実行 |

`--dry-run` と `--scope` は併用可能。併用時は指定スコープに限定したプレビューを表示する。
不正な `--scope` 値（例: `--scope foo`）が渡された場合は処理を実行せず以下の形式でエラーを返す:

```text
エラー: 不正な --scope 値 "foo" が指定されました。有効な値は user / project / local です。
```

## 重要原則

| 原則 | 根拠 ADR |
|-----|---------|
| **公式 CLI 経由**: `git fetch` / `git reset` 等の低レベル git 操作は行わない | ADR-PU-002 |
| **固定順序**: マーケットプレイス → User → Project → Local | ADR-PU-003 |
| **スコープ個別更新**: 各スコープの `enabledPlugins` が独立 SSOT のため CLI を個別呼び出し | ADR-PU-001/002 |
| **継続実行**: 個別更新でエラーが発生しても処理を中断せず次へ進む | ADR-PU-003 |
| **失敗対応の確認**: 全フェーズ完了後、失敗があれば Phase G で対応を確認 | ADR-PU-003 |
| **exit code 一次判定 + Unknown 区分**: 出力テキスト解析は補助情報に降格 | ADR-PU-005 |
| **横断ルール参照**: XR-1〜XR-4 は cross-cutting-rules.md を SSOT とする | ADR-PU-004 |

## 実行フロー

### Phase A: 対象収集（読み取りのみ）

| 項目 | 取得元 | 取得方法 |
|-----|-------|---------|
| マーケットプレイス一覧 | Claude Code CLI | `claude plugin marketplace list` |
| User プラグイン | `~/.claude/settings.json` の `enabledPlugins` | Read ツールで読み込み Claude が JSON 解析 |
| Project プラグイン | `<repo>/.claude/settings.json` の `enabledPlugins` | 同上 |
| Local プラグイン | `<repo>/.claude/settings.local.json` の `enabledPlugins` | 同上 |

`settings.json` 系の読み取りは **Read ツールで直接ファイルを読み込み、Claude 自身が JSON を解析** する。
`jq` など外部ツールは使用しない。

#### 重要: シークレット二次経路の遮断

読み取った JSON の **`enabledPlugins` キー以外（`mcpServers` / `extraKnownMarketplaces` / `hooks` 等）は
Read 直後にメインコンテキストから切り離す**。具体的手順:

1. 可能なら `Grep` で `enabledPlugins` ブロックのみを抽出して Read 範囲を絞る
2. 全文 Read が必要な場合、`enabledPlugins` の中身のみを抽出した JSON サマリを作業メモとして保持し、
   生 Read 結果はメインコンテキストの作業文字列から削除（要約後に破棄）
3. メインコンテキストには `enabledPlugins` 配下のキー・値のみを残し、後続セッションへの引き継ぎや
   結果報告に他キーが混入しないようにする

#### `<repo>` の決定と検証

`<repo>` は `git rev-parse --show-toplevel` の結果。Read ツールに渡す際は **絶対パスをダブルクォートで括る**。
以下の追加検証をすべて満たさない場合は Project / Local 処理をスキップ（理由を INFO で表示）:

- 結果に `..` を含まない
- 絶対パス（Windows: `^[A-Za-z]:\\`、POSIX: `^/`）
- 改行・null 文字を含まない
- 実在ディレクトリ（Read ツールで存在確認）
- Windows のシンボリックリンク・ジャンクション・UNC パス（`\\server\share`）は対象外

git リポジトリ外で実行され、かつ `--scope project` または `--scope local` が **明示指定** された場合は
エラーを返して中断する。`--scope` 未指定時は Project / Local を省略するが、その旨を以下の INFO で明示する:

```text
INFO: git リポジトリ外で実行されたため Project / Local スコープを対象から除外しました。
```

各プラグインエントリは **(scope, plugin-name, marketplace-name)** の 3 つ組として記録。
スコープが異なれば同一 (plugin-name, marketplace-name) でも別エントリとして扱う。

#### `enabledPlugins` のスキーマ例

Claude Code の `enabledPlugins` は **キーがプラグイン識別子（`<plugin-name>@<marketplace-name>` 形式）、
値がブール（または null）** のオブジェクト。`@` の左側が plugin-name、右側が marketplace-name。

```json
{
  "enabledPlugins": {
    "convert-doc@dmajima-claude-plugins": true,
    "extension-toolkit@dmajima-claude-plugins": true,
    "credentials-manager@dmajima-claude-plugins": false
  }
}
```

| 値 | 扱い |
|----|------|
| `true` | 有効として処理対象に含める |
| `false` / `null` | 明示的に無効化されているのでスキップ |
| 文字列 / オブジェクト等の異常値 | Skipped（不明な値型）として記録し、Phase F 備考に明示 |

### Phase A-0: Claude Code CLI 存在チェック

`claude plugin --help` を実行し exit code 0 を確認する。失敗時は以下のエラーで処理を中断する:

```text
エラー: claude plugin CLI が利用できません。Claude Code のインストール状況を確認してください。
```

### Phase A-1: 入力検証（XR-1 を適用）

抽出した各エントリについて XR-1（[cross-cutting-rules.md](../references/cross-cutting-rules.md)）を適用。
`@` で **分割した後** の plugin-name / marketplace-name 各部分と、scope 値を個別に検証する。
合致しないエントリは Phase F のサマリで「Skipped（不正な名前）」として除外し、CLI コマンドには絶対に渡さない。

### Phase A-2: マーケットプレイス整合性検証

`enabledPlugins` 内の `marketplace-name` のうち、Phase A で取得した `claude plugin marketplace list`
の結果に **存在しないもの** を Skipped（マーケットプレイス未登録）として除外する。

#### 二重実施の挙動

A-2 は **Phase A 直後に 1 回のみ実施** する。Phase B 後の再実施は行わない（仕様簡素化のため）。
Phase B でマーケットプレイスが新規追加されるケースは現実的に稀で、その場合は次回実行時に
反映される（即時性は不要）。

### Phase B: マーケットプレイス更新（最初に必ず実行・XR-1/XR-2/XR-3 を適用）

`--scope` の値にかかわらず、本フェーズは常に実行する。

```bash
claude plugin marketplace update
```

#### B-1. 結果判定

| exit code + 出力 | 判定 | 後続処理 |
|------------------|------|---------|
| exit 0 + 出力に `Failed:` / `Error:` 行なし | 全 OK | Phase C 以降を通常実行 |
| exit 0 + 出力に `Failed:` / `Error:` 行あり | 部分失敗 | 該当行から MP 名を抽出（XR-3 サニタイズ後）。**警告付き継続** |
| exit 0 + 出力解析で MP 名抽出不能 | Unknown | F-2 に Unknown 区分で残し、当該 MP 配下のプラグインは Skipped（MP Unknown）として Phase C/D/E から除外 |
| exit 非 0 | 全体失敗 | Phase C 以降は **警告付き継続**（CLI が古いインデックスでプラグイン更新を試みる可能性のため停止しない） |

CLI が将来 `--output json` を提供した場合の拡張ポイント。

### Phase C: User スコープのプラグイン更新（XR-1/XR-2/XR-3 を適用）

`--scope` が `user` または未指定の場合のみ実行（Phase B は別途常時実行済み）。
B-1 で MP Unknown 判定された MP 配下のエントリは除外。

User スコープの (plugin-name, marketplace-name) ごとに以下を実行:

```bash
claude plugin update <plugin-name>@<marketplace-name> --scope user
```

#### C-1. 結果分類（ADR-PU-005 に基づく）

結果分類テーブルは [`../references/architecture-decisions.md`](../references/architecture-decisions.md)
の ADR-PU-005 を参照（Updated / No change / Missing / Failed / Unknown の 5 区分）。

### Phase D: Project スコープのプラグイン更新（XR-1/XR-2/XR-3 を適用）

`--scope` が `project` または未指定、かつ git リポジトリ配下のときのみ実行。
処理内容は Phase C と同等で `--scope project` を指定。**結果分類は ADR-PU-005 を参照**。

### Phase E: Local スコープのプラグイン更新（XR-1/XR-2/XR-3 を適用）

`--scope` が `local` または未指定、かつ git リポジトリ配下のときのみ実行。
処理内容は Phase C と同等で `--scope local` を指定。**結果分類は ADR-PU-005 を参照**。

### Phase F: 結果報告

すべての更新処理を完了した時点で、以下の構造で **必ず結果報告** を提示する。
変数表記の `<count>` 等は Claude が実行時に実際の値に置き換える。

#### F-0. CLI 出力サニタイズ（XR-3 を参照）

サニタイズ規則本体は [`../references/cross-cutting-rules.md`](../references/cross-cutting-rules.md) の
XR-3 セクションに定義。本 Phase F-2 / F-3 / G-2 で備考列を生成する直前に必ず適用する。

**重要な例外**: テーブルの `プラグイン名` 列・`マーケットプレイス名` 列・`結果` 列には
**デフォルトマスク（40 字超ランダム文字列のマスク）を一切適用しない**
（プラグイン名・コミットハッシュ・バージョン識別子の誤検知防止）。
具体パターン（GitHub PAT 等）は備考列のみで適用。

#### F-1. サマリ

```markdown
## 更新結果サマリ

| 区分 | 成功 | 変更なし | Missing | スキップ | 失敗 | Unknown |
|-----|-----|---------|---------|---------|-----|---------|
| マーケットプレイス | <count> | <count> | - | <count> | <count> | <count> |
| User プラグイン | <count> | <count> | <count> | <count> | <count> | <count> |
| Project プラグイン | <count> | <count> | <count> | <count> | <count> | <count> |
| Local プラグイン | <count> | <count> | <count> | <count> | <count> | <count> |
```

#### F-1.1. Unknown 警告

Unknown 件数が **全体（マーケットプレイス + 全スコーププラグインの合計）の 20%** を超える場合、
以下の警告を併記する:

```text
警告: Unknown 件数が全体の 20% を超えています（<U>/<T> 件）。CLI 出力フォーマットが変わった可能性が
あるため、F-2/F-3 の備考列を確認し、必要なら個別に手動更新してください。
```

#### F-2. マーケットプレイス詳細

```markdown
### マーケットプレイス

| マーケットプレイス | 結果 | 備考 |
|-----------------|-----|-----|
| <name> | OK / Skipped / Failed / Unknown | <サニタイズ後の CLI 出力要約 or エラー> |
```

#### F-3. スコープ別詳細

```markdown
### User プラグイン

| プラグイン | マーケットプレイス | 結果 | 備考 |
|----------|-----------------|-----|-----|
| <plugin> | <marketplace> | Updated / No change / Missing / Failed / Unknown | <サニタイズ後の備考> |

### Project プラグイン
（User と同形式。git リポジトリ外なら "リポジトリ外のため省略" を表示）

### Local プラグイン
（User と同形式。git リポジトリ外なら "リポジトリ外のため省略" を表示）
```

#### F-4. 次のアクション提示

`--dry-run` モード時は本セクションを **省略** する（実際の更新がないため）。

```markdown
### 次のアクション

- Claude Code を再起動するか `/reload-plugins` を実行して更新をセッションに反映する
- **重要**: 更新によって新しい hooks / MCP サーバ / commands / agents が追加された可能性があります。
  再起動前に以下を **必ず** 実施してください:

  ```text
  claude plugin show <plugin>@<marketplace>
  ```

  特に `hooks` セクションが新規追加・変更されている場合、次回起動時に自動実行されます。
- Missing と判定されたエントリは `enabledPlugins` から除外することを検討（マーケットプレイスから消失）
- 更新後に問題が発覚した場合のロールバックは README の「ロールバック手順」セクションを参照
- （失敗があれば）次のリトライ・スキップ確認に応答する
```

### Phase G: 失敗対応の確認（失敗ありの場合のみ）

Phase F の結果報告後、**失敗が 1 件以上ある場合** に実行。
失敗総数 `<N>` の定義は「Failed + Missing の合計」（Unknown は要手動確認のため除外）。

#### G-1. 全体方針の確認（疑似コード）

```text
# pseudocode: Claude が AskUserQuestion ツールを呼び出すパターン
AskUserQuestion({
  questions: [{
    question: "<N> 件の更新失敗があります（マーケットプレイス: <M> 件 / プラグイン: <P> 件）。どう対応しますか？",
    header: "更新失敗対応",
    options: [
      { label: "全件リトライ", description: "失敗した全エントリをもう一度更新する" },
      { label: "個別に判断", description: "失敗エントリごとにリトライ / スキップを選択" },
      { label: "全件スキップ", description: "失敗エントリは諦めて完了する" }
    ],
    multiSelect: false
  }]
})
```

**G-1 の選択肢に応じた分岐**:
- 「全件リトライ」 → G-3 を全失敗エントリに対して実行
- 「個別に判断」 → G-2 へ進む（失敗 5 件以下の場合のみ。6 件以上は G-1 のみで打ち切り）
- 「全件スキップ」 → G-3 / G-4 をスキップして終了

#### G-2. 個別判断モード（G-1 で「個別に判断」が選択された場合のみ実行）

失敗エントリ数（Failed + Missing。Unknown は除外）が **5 件以下の場合のみ** 各エントリについて確認する。
6 件以上の場合は G-1 で本モードは選択肢から除外する（実装側で制御）。

質問テキストの `<error>` は XR-3 サニタイズ後の値。500 字を超える場合は「...（省略）」で切り詰める。

```text
# pseudocode: Claude が AskUserQuestion ツールを呼び出すパターン
AskUserQuestion({
  questions: [{
    question: "[<scope>] <plugin>@<marketplace> の更新に失敗しました（理由: <サニタイズ後のerror>）。リトライしますか？",
    header: "個別失敗対応",
    options: [
      { label: "リトライ", description: "もう一度更新を試行" },
      { label: "スキップ", description: "このエントリは諦める" }
    ],
    multiSelect: false
  }]
})
```

#### G-3. リトライ実行（XR-1/XR-2/XR-3/XR-4 を適用）

リトライは失敗種別に応じて **必要最小限のフェーズのみ** 再実行する。
XR-2 のサーキットブレーカー作動中の MP には適用しない。

| 失敗種別 | 再実行範囲 |
|---------|-----------|
| マーケットプレイス失敗 | **現状は全件リトライにフォールバック**（CLI が `claude plugin marketplace update <name>` の引数指定を確認できないため）。CLI が個別指定をサポートした際にこの箇所を更新する |
| プラグイン更新失敗（C/D/E 由来） | `claude plugin update <plugin>@<marketplace> --scope <scope>` を当該エントリのみ実行 |

XR-4 によりリトライは元の失敗集合に対し最大 1 回。リトライ中の新規失敗は記録のみ。

#### G-4. リトライ完了後の最終報告（追記出力）

リトライ完了後、Phase F のサマリ・詳細テーブルを **同一フォーマットで再度出力** する
（チャット UI では前の出力を上書きできないため、新たなセクションとして追記）。

各エントリの **備考列** にリトライ前後の状態変化を記載する:
- `Failed → Updated（リトライ成功）`
- `Failed → Failed（リトライ失敗）`
- `Missing → No change（CLI 側で見つかった）`

追記版が最終結果として確定する。

## --dry-run モード時の挙動

`--dry-run` 指定時は **実際の更新コマンドを一切実行せず**、以下のみ提示する。

- Phase A の対象収集は通常通り実行（Read ツールで `settings.json` 系を読み込み、`claude plugin marketplace list` を実行。
  `marketplace list` はキャッシュ参照のみで更新通信を行わないことが期待されるが、CLI バージョンにより異なる場合がある）
- Phase A-0 / A-1 / A-2 の検証も実行
- Phase B / C / D / E の代わりに、実行予定の CLI コマンド一覧を Phase F と同形式のテーブルで表示
  - 「結果」列の代わりに「実行予定コマンド」列を表示
- Phase F-4 / G はスキップ

**重要な制約**: `--dry-run` は **実行予定のコマンド一覧** のみを提示します。
**各プラグインの変更内容（新規 hooks / MCP / agents の追加）は確認しません**。
変更内容の確認には実行後 `claude plugin show <plugin>@<marketplace>` を別途実行する必要があります。

## 注意事項

- 本コマンドは Claude Code 公式 CLI に処理を委譲するため、**ローカル変更の意図しない破壊や
  ブランチ強制移動は発生しない**（CLI 内部のロック制御・状態管理に依存）。
- スコープ別更新で同一プラグインを複数回処理しても、CLI が冪等性を保証する。
- プライベートリポジトリのマーケットプレイスは Git credential helper / SSH キーの設定が前提。
  認証エラー時の詳細は CLI 出力に依存する（XR-3 サニタイズで認証情報を伏せる）。
- **CLI 不在時の動作**: A-0 で検出してエラー終了。Phase B 以降は実行しない。
- `claude plugin update` は **再起動が必要** と公式が明示しているため、本コマンド完了後は
  `/reload-plugins` か Claude Code 再起動を促す。
- **サプライチェーンリスク**: マーケットプレイス更新により新しい `hooks` / `commands` / `agents` /
  MCP サーバが引き込まれた場合、次回 Claude Code 起動時に **自動実行** される。
  - `--dry-run` で確認できるのは「実行する CLI コマンド」だけで、引き込まれる **新規 hooks の内容は
    確認できない**。再起動前に `claude plugin show <plugin>@<marketplace>` で個別に確認すること。
  - 信頼するマーケットプレイスのみで本コマンドを使用すること。
  - `autoUpdate: true` セッション起動時自動更新と `/update-all` 手動更新が同時に走った場合、
    CLI 内部のロック挙動に依存する（一方が待機する想定）。
- リトライは 1 回まで（合計 2 試行・XR-4）。それでも解消しない場合はネットワーク・認証・対象ファイルの
  状態を個別に調査する必要がある。

## 関連

- [`../references/architecture-decisions.md`](../references/architecture-decisions.md) — ADR-PU-001〜005
- [`../references/cross-cutting-rules.md`](../references/cross-cutting-rules.md) — XR-1〜XR-4 SSOT
- グローバルルール `~/.claude/rules/claude/plugin-auto-update.md`（自動更新ポリシー）
- `extension-toolkit:marketplace-toolkit`（マーケットプレイス本体管理）
- `extension-toolkit:marketplace-publisher`（マーケットプレイスへの公開）
