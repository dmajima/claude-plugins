---
description: 公式 CLI でマーケットプレイス・プラグインを一括最新化
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

横断ルール **XR-1〜XR-5** の SSOT は [`../references/cross-cutting-rules.md`](../references/cross-cutting-rules.md)。
本コマンドでは各 Phase が下表のどの XR を適用するかのみを示す。規則本体・閾値・例外条項はすべて SSOT を参照のこと。

| ID | ルール | 本コマンドでの適用 Phase |
|----|------|----------------------|
| XR-1 | 入力検証 | A-1 / B / C / D / E / G-3 |
| XR-2 | タイムアウト + サーキットブレーカー | B / C / D / E / G-3 |
| XR-3 | 出力サニタイズ | F-2 / F-3 / G-2 / B-1 例外行抽出時 |
| XR-4 | リトライ上限（最大 1 回） | G-3 |
| XR-5 | Unknown 警告閾値 | F-1 |

## 動作モード判定

`--scope` 指定の有無にかかわらず、**Phase B（マーケットプレイス更新）は常に実行する**。
スコープ限定はプラグイン更新（Phase C〜E）のみが対象。

| 引数 | モード | 動作 |
|-----|-------|------|
| 空 | 通常更新（全スコープ） | Phase A-0〜G を実行 |
| `--dry-run` | 確認のみ | 全 Phase（B/C/D/E）の実行予定 CLI を表示。実際の更新は行わない |
| `--scope user` | スコープ限定 | Phase B を **必ず実行** した後、Phase C のみ実行 |
| `--scope project` | スコープ限定 | Phase B を必ず実行した後、Phase D のみ実行 |
| `--scope local` | スコープ限定 | Phase B を必ず実行した後、Phase E のみ実行 |
| `--dry-run --scope user` | dry-run + 限定 | Phase B + Phase C の **実行予定 CLI のみ表示** |
| `--dry-run --scope project` | dry-run + 限定 | Phase B + Phase D の実行予定 CLI のみ表示 |
| `--dry-run --scope local` | dry-run + 限定 | Phase B + Phase E の実行予定 CLI のみ表示 |

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

実行順は **A-0 → A → A-1 → A-2 → B → C → D → E → F → G**。
A-0 は Phase A の前に必ず実行する（CLI 不在時の早期失敗）。

### Phase A-0: Claude Code CLI 存在チェック（最優先実行）

`claude plugin --help` を実行し以下を満たすことを確認する:

- exit code が 0
- 出力に `marketplace` および `update` の両キーワードを含む（同名の悪意あるシム検出のため）

いずれかを満たさない場合は以下のエラーで処理を中断する:

```text
エラー: claude plugin CLI が利用できません（または不正な実装の可能性）。
Claude Code のインストール状況と PATH を確認してください。
```

### Phase A: 対象収集（読み取りのみ）

| 項目 | 取得元 | 取得方法 |
|-----|-------|---------|
| マーケットプレイス一覧 | Claude Code CLI | `claude plugin marketplace list` |
| User プラグイン | `~/.claude/settings.json` の `enabledPlugins` | Read ツールで読み込み Claude が JSON 解析 |
| Project プラグイン | `<repo>/.claude/settings.json` の `enabledPlugins` | 同上 |
| Local プラグイン | `<repo>/.claude/settings.local.json` の `enabledPlugins` | 同上 |

`settings.json` 系の読み取りは **Read ツールで直接ファイルを読み込み、Claude 自身が JSON を解析** する。
`jq` など外部ツールは使用しない。

#### 重要: シークレット二次経路の遮断（必須手順）

読み取った JSON の **`enabledPlugins` キー以外（`mcpServers` / `extraKnownMarketplaces` / `hooks` 等）は
メインコンテキストに一切載せない**。以下の手順を **必ず順守**する:

1. **第一手順（必須）**: `Grep` で `enabledPlugins` の開始ブロックのみを `-A 200` 程度で抽出して、
   Read 対象範囲を `enabledPlugins` セクションに限定する
   ```text
   Grep(pattern: '"enabledPlugins"', path: '<settings.json>', output_mode: 'content', -A: 200)
   ```
2. **フォールバック（Grep 失敗時のみ）**: 全文 Read を行うが、`enabledPlugins` 配下のキー・値のみを
   作業メモに転記し、生 Read 結果文字列は **直後に破棄**（メインコンテキストの作業変数を上書き）
3. **抽出失敗時の検知**: `enabledPlugins` キーが見つからない場合は当該スコープを「対象なし」として
   扱い、Phase F に空テーブルで報告（エラー扱いにはしない）
4. メインコンテキストには `enabledPlugins` 配下のキー・値のみを残し、後続セッションへの引き継ぎや
   結果報告に他キーが混入しないようにする

#### `<repo>` の決定と検証

`<repo>` は `git rev-parse --show-toplevel` の結果。検証ルールは XR-1 の「パス検証」セクション
（[cross-cutting-rules.md](../references/cross-cutting-rules.md)）を参照。検証失敗時は Project / Local
処理をスキップして INFO で理由を表示する（フェイルクローズ）。

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

結果分類テーブル（マーケットプレイス更新用）は ADR-PU-005 の「結果分類テーブル — マーケットプレイス更新（B-1）」
セクション（[`../references/architecture-decisions.md`](../references/architecture-decisions.md)）を参照。
例外行抽出パターン・Unknown 区分の扱いも ADR-PU-005 に集約されている。

### Phase C / D / E: スコープ別プラグイン更新（XR-1/XR-2/XR-3 を適用）

各スコープの (plugin-name, marketplace-name) ごとに以下を実行する:

```bash
# Phase C: User スコープ（--scope が user または未指定のとき）
claude plugin update <plugin-name>@<marketplace-name> --scope user

# Phase D: Project スコープ（--scope が project または未指定、かつ git リポジトリ配下のとき）
claude plugin update <plugin-name>@<marketplace-name> --scope project

# Phase E: Local スコープ（--scope が local または未指定、かつ git リポジトリ配下のとき）
claude plugin update <plugin-name>@<marketplace-name> --scope local
```

B-1 で MP Unknown 判定された MP 配下のエントリは除外する。

#### C-1 / D-1 / E-1. 結果分類（ADR-PU-005 に基づく）

結果分類テーブル（プラグイン更新用）は ADR-PU-005 の「結果分類テーブル — プラグイン更新（C-1 / D-1 / E-1 共通）」
セクションを参照（Updated / No change / Missing / Failed / Unknown の 5 区分）。
3 スコープすべてで同一テーブルを適用する。

### Phase F: 結果報告

すべての更新処理を完了した時点で、以下の構造で **必ず結果報告** を提示する。
変数表記の `<count>` 等は Claude が実行時に実際の値に置き換える。

#### F-0. CLI 出力サニタイズ（XR-3 を参照）

サニタイズ規則本体・列単位の例外・「文脈外」判定の具体ルールはすべて
[`../references/cross-cutting-rules.md`](../references/cross-cutting-rules.md) の XR-3 セクションに定義。
本 Phase F-2 / F-3 / G-2 で備考列を生成する直前に必ず適用する。

#### F-1. サマリ

`Missing` 列は B-1（マーケットプレイス更新）では現在の CLI が MP 単位の Missing を返さないため `-` 固定
（将来 CLI が MP レベルで `not found` を返すようになった場合は仕様改訂）。

```markdown
## 更新結果サマリ

| 区分 | 成功 | 変更なし | Missing | スキップ | 失敗 | Unknown |
|-----|-----|---------|---------|---------|-----|---------|
| マーケットプレイス | <count> | <count> | -（CLI 非対応）| <count> | <count> | <count> |
| User プラグイン | <count> | <count> | <count> | <count> | <count> | <count> |
| Project プラグイン | <count> | <count> | <count> | <count> | <count> | <count> |
| Local プラグイン | <count> | <count> | <count> | <count> | <count> | <count> |
```

#### F-1.1. Unknown 警告（XR-5 を参照）

XR-5 の閾値（試行済み件数の 20%）を超える場合、cross-cutting-rules.md XR-5 セクションのフォーマットで
警告を併記する。閾値の根拠と全体件数の定義は同セクションを参照。

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
# N > 5 の場合は options から「個別に判断」を除外する（連続質問による UX 劣化防止）
AskUserQuestion({
  questions: [{
    question: "<N> 件の更新失敗があります（マーケットプレイス: <M> 件 / プラグイン: <P> 件）。どう対応しますか？",
    header: "更新失敗対応",
    options: [
      { label: "全件リトライ", description: "失敗した全エントリをもう一度更新する" },
      // N <= 5 のときのみ次の選択肢を含める
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
| マーケットプレイス失敗 | **Phase B を再度実行する（全マーケットプレイス対象 = `claude plugin marketplace update` を引数なしで再実行）**。CLI が `claude plugin marketplace update <name>` の引数指定をサポートしていることが確認できたら個別 MP リトライに切り替える（ADR-PU-002 Future Direction 参照） |
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
