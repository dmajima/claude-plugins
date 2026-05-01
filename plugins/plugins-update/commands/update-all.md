---
description: 公式 CLI でマーケットプレイス・プラグインを一括最新化（--dry-run/--scope）
argument-hint: "[--dry-run] [--scope <user|project|local>]"
---

ユーザの引数: $ARGUMENTS

Claude Code 公式 CLI（`claude plugin marketplace update` / `claude plugin update`）を経由して
インストール済みマーケットプレイスとプラグインを **一括で最新版に更新** するコマンド。
**マーケットプレイス更新 → User → Project → Local の固定順** で処理し、同一プラグインが
複数スコープに存在する場合も **スコープごとに個別に更新** する。

## 動作モード判定

`--scope` 指定の有無にかかわらず、**Phase B（マーケットプレイス更新）は常に実行する**。
スコープ限定はプラグイン更新（Phase C〜E）のみが対象。

| 引数 | モード | 動作 |
|-----|-------|------|
| 空 | 通常更新（全スコープ） | Phase A〜G を実行 |
| `--dry-run` | 確認のみ | 実行予定のコマンド一覧を提示。実際の更新は行わない |
| `--scope user` | スコープ限定 | Phase B（マーケットプレイス更新）を **必ず実行** した後、Phase C のみ実行 |
| `--scope project` | スコープ限定 | Phase B を必ず実行した後、Phase D のみ実行 |
| `--scope local` | スコープ限定 | Phase B を必ず実行した後、Phase E のみ実行 |
| 指定なし | 通常更新 | `--scope` 省略時は全スコープが対象 |

`--dry-run` と `--scope` は併用可能。併用時は指定スコープに限定したプレビューを表示する。
不正な `--scope` 値（例: `--scope foo`）が渡された場合は処理を実行せず、以下の形式でエラーを返す:

```text
エラー: 不正な --scope 値 "foo" が指定されました。有効な値は user / project / local です。
```

## 重要原則

| 原則 | 内容 |
|-----|------|
| **公式 CLI 経由** | `claude plugin marketplace update` / `claude plugin update` を呼び出す。`git fetch` / `git reset` 等の低レベル git 操作は行わない |
| **固定順序** | マーケットプレイス → User → Project → Local の順序を厳守。順序を入れ替えない |
| **スコープ個別更新** | 同一プラグインが複数スコープにある場合、各スコープで個別に CLI を呼ぶ（`enabledPlugins` がスコープごとに独立 SSOT であるため） |
| **継続実行** | 個別更新でエラーが発生しても処理を **中断せず** 次の対象へ進む。エラーは記録し最後に集計する |
| **失敗対応の確認** | 全フェーズ完了後、失敗があれば結果報告に続けてユーザにリトライ・スキップの対応を確認する |
| **exit code 一次判定** | CLI の成否は exit code を真実の源泉とし、出力テキストの解析は補助情報に降格する（CLI バージョン非依存性の確保） |

順序の根拠:
- マーケットプレイス更新を先に行う理由: マーケットプレイス本体が SSOT のため、最新化してからプラグイン更新を行わないと旧版のまま処理される。
- スコープ順 (User → Project → Local) の理由: 上書き優先順位（より狭いスコープが優先される）の逆順で更新することで、より広いスコープから順に最新化する。

## 実行フロー

### Phase A: 対象収集（読み取りのみ）

| 項目 | 取得元 | 取得方法 |
|-----|-------|---------|
| マーケットプレイス一覧 | Claude Code CLI | `claude plugin marketplace list` |
| User プラグイン | `~/.claude/settings.json` の `enabledPlugins` | Read ツールで読み込み Claude が JSON 解析 |
| Project プラグイン | `<repo>/.claude/settings.json` の `enabledPlugins` | 同上 |
| Local プラグイン | `<repo>/.claude/settings.local.json` の `enabledPlugins` | 同上 |

`settings.json` 系の読み取りは **Read ツールで直接ファイルを読み込み、Claude 自身が JSON を解析** する。
`jq` など外部ツールは使用しない（環境差異によるエラー回避のため）。

`<repo>` は `git rev-parse --show-toplevel` の結果。git リポジトリ外で実行され、
かつ `--scope project` または `--scope local` が **明示指定** された場合は、
エラーメッセージを表示して処理を中断する。`--scope` 未指定時は Project / Local を黙って省略する。

各プラグインエントリは **(scope, plugin-name, marketplace-name)** の 3 つ組として記録し、
スコープが異なれば同一 (plugin-name, marketplace-name) でも別エントリとして扱う。

`enabledPlugins` の値が JSON の `false` または `null` のエントリはスキップする。
それ以外（`true` / 文字列 / オブジェクト等）は有効として扱う。

#### A-1. プラグイン名・マーケットプレイス名の入力検証

抽出した各 (plugin-name, marketplace-name) について、以下の正規表現にマッチしないものは
Phase F のサマリで「Skipped（不正な名前）」として除外し、CLI コマンドに渡さない:

```text
^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$
```

シェルメタ文字（`;` `|` `&` `` ` `` `$` `<` `>` 改行・空白）を含むエントリは即拒否する。
これは悪意あるマーケットプレイスからの引数注入（CWE-78 / CWE-88）への防御。

### Phase B: マーケットプレイス更新（最初に必ず実行）

`--scope` の値にかかわらず、本フェーズは常に実行する。
公式 CLI でマーケットプレイス全件を一括更新する。

```bash
claude plugin marketplace update
```

このコマンドは Claude Code が内部で各マーケットプレイスのソース（`github` / `git` / `path`）に
応じた更新処理を行う。手動の `git fetch` / `git reset --hard` は **不要かつ実行禁止**
（ローカル変更の意図しない破壊・ロールバック手段の喪失を防ぐため）。

#### B-1. 結果判定（exit code 一次・出力解析は補助）

| exit code | 判定 |
|----------|------|
| 0 | 成功。出力中の `Failed:` / `Error:` 行があればその行から MP 名を抽出し失敗として記録、それ以外は OK |
| 非 0 | 全体失敗として記録。Phase C 以降は警告付きで継続（CLI が古いインデックスでプラグイン更新を試みる可能性があるため停止しない） |

出力の解析は補助情報であり、抽出不能な行は "Unknown（要手動確認）" として Phase F に残す。
CLI が将来 `--output json` を提供した場合に備え、この箇所は拡張ポイントとして残す。

#### B-2. タイムアウト

CLI 呼び出しは **概ね 60 秒** をタイムアウトの目安とする。超過時は当該呼び出しを Failed として記録し、
次の処理へ進む（DoS 回避）。

### Phase C: User スコープのプラグイン更新

`--scope` が `user` または未指定の場合のみ実行（Phase B は別途常時実行済み）。

User スコープの (plugin-name, marketplace-name) ごとに以下を実行する:

```bash
claude plugin update <plugin-name>@<marketplace-name> --scope user
```

| 結果分類 | 判定基準（exit code 一次） |
|---------|--------------------------|
| Updated | exit 0 + 出力に `updated` 相当のメッセージ |
| No change | exit 0 + 出力に `up-to-date` / `already latest` 相当 |
| Missing | exit 非 0 + 出力に `not found` / `no such plugin` 相当（マーケットプレイスに不在） |
| Failed | 上記以外の exit 非 0（ネットワーク・認証等） |
| Unknown | exit 0 だがいずれの相当文字列も検出できない場合（要手動確認） |

例外発生時はエラー内容を記録し、次のエントリに進む（Phase B-2 のタイムアウトを適用）。

### Phase D: Project スコープのプラグイン更新

`--scope` が `project` または未指定の場合、かつ git リポジトリ配下のときのみ実行。
処理内容は Phase C と同等で `--scope project` を指定する。

### Phase E: Local スコープのプラグイン更新

`--scope` が `local` または未指定の場合、かつ git リポジトリ配下のときのみ実行。
処理内容は Phase C と同等で `--scope local` を指定する。

### Phase F: 結果報告

すべての更新処理を完了した時点で、以下の構造で **必ず結果報告** を提示する。
変数表記の `<count>` 等は Claude が実行時に実際の値に置き換える。

#### F-0. CLI 出力のサニタイズ（必須）

Phase F-2 / F-3 / G-2 で CLI 出力を表示する際は、**事前に以下のサニタイズを必ず適用** する。
ログ共有・スクリーンショット添付時の認証情報露出（CWE-209 / CWE-532）を防ぐため。

| パターン | 置換後 |
|---------|-------|
| `(?i)(token\|password\|secret\|authorization\|bearer\|x-api-key)[:=]\s*\S+` | `<key>=***REDACTED***` |
| `https?://[^/\s]+:[^@\s]+@` | `https://***@` |
| `/[\w./-]+\.pem`、`id_rsa`、`id_ed25519` 等の SSH 鍵パス | `<ssh-key-path>` |

#### F-1. サマリ

```markdown
## 更新結果サマリ

| 区分 | 成功 | 変更なし | スキップ | 失敗 |
|-----|-----|---------|---------|-----|
| マーケットプレイス | <count> | <count> | <count> | <count> |
| User プラグイン | <count> | <count> | <count> | <count> |
| Project プラグイン | <count> | <count> | <count> | <count> |
| Local プラグイン | <count> | <count> | <count> | <count> |
```

「変更なし」は CLI が `up-to-date` 相当を返したケースを集計する。
Unknown 区分は「失敗」と別に注記し、Phase F-2/F-3 の備考列で対象を明示する。

#### F-2. マーケットプレイス詳細

```markdown
### マーケットプレイス

| マーケットプレイス | 結果 | 備考 |
|-----------------|-----|-----|
| <name> | OK / Skipped / Failed / Unknown | <サニタイズ後の CLI 出力要約 or エラー> |
```

`git` 操作を行わないため SHA は表示しない。詳細は `claude plugin marketplace list` で確認可能。

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
  （`claude plugin update` は **再起動が必要** と公式 CLI が明示している）
- 新しい hooks / MCP サーバ / commands が追加された場合、次回起動時に自動実行される。
  心配な場合は `claude plugin show <plugin>@<marketplace>` で内容を確認してから再起動する
- 更新後に問題が発覚した場合のロールバック:
  1. `claude plugin uninstall <plugin>@<marketplace>` で旧版含めアンインストール
  2. マーケットプレイスの旧版タグへ切り替え（必要なら `git checkout <tag>` をローカル複製先で実施）
  3. `claude plugin install <plugin>@<marketplace>` で再インストール
- （失敗があれば）次のリトライ・スキップ確認に応答する
```

### Phase G: 失敗対応の確認（失敗ありの場合のみ）

Phase F の結果報告後、**失敗が 1 件以上ある場合** は `AskUserQuestion` で以下を確認する。
質問文の `<N>` には失敗総数を、内訳には Phase B と Phase C〜E の失敗件数を入れる。
Unknown 区分は失敗扱いに含めない（要手動確認として F-2/F-3 で表示するに留める）。

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

#### G-2. 個別判断モードの場合

失敗エントリ数が **5 件以下** の場合は各エントリについて 1 つずつ確認する:

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

失敗エントリ数が **6 件以上** の場合は連続質問が UX を著しく損なうため、
G-1 の「全件リトライ / 全件スキップ」のみ提示し、個別判断モードはスキップする。

#### G-3. リトライ実行（範囲限定）

リトライは失敗種別に応じて **必要最小限のフェーズのみ** 再実行する。

| 失敗種別 | 再実行範囲 |
|---------|-----------|
| マーケットプレイス失敗 | `claude plugin marketplace update <name>` を当該マーケットプレイスのみ実行（CLI が引数で個別指定をサポートする場合）。サポートしない場合は全件リトライにフォールバック |
| プラグイン更新失敗（C/D/E 由来） | `claude plugin update <plugin>@<marketplace> --scope <scope>` を当該エントリのみ実行 |

リトライは **元の失敗集合に対してのみ** 行う（最大 1 回 = 合計 2 試行）。
リトライ中に新たに発生した失敗は記録のみとし、再度 Phase G を起動しない（無限ループ防止）。

#### G-4. リトライ完了後の最終報告

リトライ完了後、Phase F のサマリ・詳細テーブルを **再描画** する。
再描画版を最終結果として確定する。新規失敗が増えた場合も同テーブル内に反映する。

## --dry-run モード時の挙動

`--dry-run` 指定時は **実際の更新コマンドを一切実行せず**、以下のみ提示する。

- Phase A の対象収集は通常通り実行（読み取りのみ。`claude plugin marketplace list` はローカルキャッシュを参照し外部通信なし）
- Phase B / C / D / E の代わりに、実行予定の CLI コマンド一覧を Phase F と同形式のテーブルで表示
  - 「結果」列の代わりに「実行予定コマンド」列を表示
- Phase F-4 はスキップ（再起動指示が不要なため）
- Phase G はスキップ（失敗が発生しないため）

`--scope` と組み合わせた場合（例: `--dry-run --scope user`）は、
指定スコープに限定したプレビューを表示する。

## 注意事項

- 本コマンドは Claude Code 公式 CLI に処理を委譲するため、**ローカル変更の意図しない破壊や
  ブランチ強制移動は発生しない**（CLI 内部のロック制御・状態管理に依存）。
- スコープ別更新で同一プラグインを複数回処理しても、CLI が冪等性を保証する（既に最新なら "No change"）。
- プライベートリポジトリのマーケットプレイスは Git credential helper / SSH キーの設定が前提。
  認証エラー時の詳細は CLI 出力に依存する（Phase F-0 のサニタイズで認証情報を伏せる）。
- `claude plugin update` は **再起動が必要** と公式が明示しているため、
  本コマンド完了後は `/reload-plugins` か Claude Code 再起動を促す。
- **サプライチェーンリスク**: 更新により新しい `hooks` / `commands` / `agents` / MCP サーバが
  引き込まれた場合、次回 Claude Code 起動時に自動実行される可能性がある。信頼するマーケットプレイスのみで
  本コマンドを使用すること。リスクを抑えたい場合は `--dry-run` で対象を確認してから実行する。
- リトライは 1 回まで（合計 2 試行）。それでも解消しない場合はネットワーク・認証・対象ファイルの
  状態を個別に調査する必要がある。

## 関連

- グローバルルール `~/.claude/rules/claude/plugin-auto-update.md`（自動更新ポリシー）
- `extension-toolkit:marketplace-toolkit`（マーケットプレイス本体管理）
- `extension-toolkit:marketplace-publisher`（マーケットプレイスへの公開）
