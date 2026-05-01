---
description: 公式 CLI でマーケットプレイス・プラグインを一括最新化
argument-hint: "[--dry-run] [--scope <user|project|local>]"
---

ユーザの引数: $ARGUMENTS

Claude Code 公式 CLI（`claude plugin marketplace update` / `claude plugin update`）を経由して
インストール済みマーケットプレイスとプラグインを **一括で最新版に更新** するコマンド。
**マーケットプレイス更新 → User → Project → Local の固定順** で処理し、同一プラグインが
複数スコープに存在する場合も **スコープごとに個別に更新** する。

設計判断の詳細は [`../references/architecture-decisions.md`](../references/architecture-decisions.md) を参照。

## 横断ルール（全 Phase 共通）

各 Phase はここで定義された 4 つの横断関心事に従う。Phase 内で個別に再定義しない。

| ID | ルール | 適用対象 |
|----|------|---------|
| **XR-1** 入力検証 | プラグイン名・マーケットプレイス名・スコープ名を正規表現 `^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$`（NFKC 正規化後）に照合し、合致しないエントリは Skipped（不正な名前）として除外。スコープ名は加えて `user\|project\|local` のホワイトリストにも合致させる | A-1 / B / C / D / E / G-3 |
| **XR-2** タイムアウト | 個別 CLI 呼び出しは概ね 60 秒で打ち切り Failed として記録し次へ進む。全体実行は 30 分上限とし、超過時は残エントリを Skipped（全体タイムアウト）として終了 | B / C / D / E / G-3 |
| **XR-3** 出力サニタイズ | CLI 出力をユーザに表示する前に、F-0 のサニタイズ規則を必ず適用 | F-2 / F-3 / G-2 / B-1 の例外行抽出時 |
| **XR-4** リトライ上限 | リトライは元の失敗集合に対し最大 1 回（合計 2 試行）。リトライ中の新規失敗は記録のみで再 Phase G を起動しない | G-3 |

## 動作モード判定

`--scope` 指定の有無にかかわらず、**Phase B（マーケットプレイス更新）は常に実行する**。
スコープ限定はプラグイン更新（Phase C〜E）のみが対象。

| 引数 | モード | 動作 |
|-----|-------|------|
| 空 | 通常更新（全スコープ） | Phase A〜G を実行 |
| `--dry-run` | 確認のみ | 実行予定のコマンド一覧を提示。実際の更新は行わない |
| `--scope user` | スコープ限定 | Phase B を **必ず実行** した後、Phase C のみ実行 |
| `--scope project` | スコープ限定 | Phase B を必ず実行した後、Phase D のみ実行 |
| `--scope local` | スコープ限定 | Phase B を必ず実行した後、Phase E のみ実行 |
| 指定なし | 通常更新 | `--scope` 省略時は全スコープが対象 |

`--dry-run` と `--scope` は併用可能。併用時は指定スコープに限定したプレビューを表示する。
不正な `--scope` 値（例: `--scope foo`）が渡された場合は処理を実行せず以下の形式でエラーを返す:

```text
エラー: 不正な --scope 値 "foo" が指定されました。有効な値は user / project / local です。
```

## 重要原則

| 原則 | 内容 |
|-----|------|
| **公式 CLI 経由** | `claude plugin marketplace update` / `claude plugin update` を呼び出す。`git fetch` / `git reset` 等の低レベル git 操作は行わない |
| **固定順序** | マーケットプレイス → User → Project → Local の順序を厳守 |
| **スコープ個別更新** | 同一プラグインが複数スコープにある場合、各スコープで個別に CLI を呼ぶ（`enabledPlugins` がスコープごとに独立 SSOT であるため） |
| **継続実行** | 個別更新でエラーが発生しても処理を **中断せず** 次の対象へ進む |
| **失敗対応の確認** | 全フェーズ完了後、失敗があれば Phase G で対応を確認 |
| **exit code 一次判定** | CLI の成否は exit code を真実の源泉とし、出力テキスト解析は補助情報に降格 |

順序の根拠は ADR-PU-003 を参照。

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

読み取った JSON の **`enabledPlugins` キー以外（`mcpServers` / `extraKnownMarketplaces` / `hooks` 等）は
即座に破棄** し、Claude のメモ・結果報告に転記しない（シークレット二次経路の遮断）。

`<repo>` は `git rev-parse --show-toplevel` の結果。Read ツールに渡す際は **絶対パスをダブルクォートで括る**。
結果が `..` を含む場合は拒否する。git リポジトリ外で実行され、かつ `--scope project` または
`--scope local` が **明示指定** された場合はエラーを返して中断する。`--scope` 未指定時は
Project / Local を省略するが、その旨を以下の INFO メッセージで明示する:

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
| `true` / 文字列 / オブジェクト | 有効として処理対象に含める |
| `false` / `null` | 明示的に無効化されているのでスキップ |

### Phase A-1: 入力検証

抽出した各エントリについて XR-1 を適用する。検証は **NFKC 正規化後** に正規表現照合。
合致しないエントリは Phase F のサマリで「Skipped（不正な名前）」として除外し、
CLI コマンドには絶対に渡さない（CWE-78 / CWE-88 防御）。

CLI 引数の組み立ては **配列要素として渡し、文字列連結後にシェル展開しない**。
`<plugin>@<marketplace>` 形式は `@` を 1 個のみ許容（複数あればエントリ拒否）。

### Phase A-2: マーケットプレイス整合性検証

`enabledPlugins` 内の `marketplace-name` のうち、Phase A で取得した `claude plugin marketplace list`
の結果に **存在しないもの** は早期に Skipped（マーケットプレイス未登録）として除外する。
Phase B 後に再度実施しても可（マーケットプレイス更新により参照可能になる場合がある）。

これにより不要な CLI 呼び出しと Phase G の無用な失敗対応質問を抑制する。

### Phase B: マーケットプレイス更新（最初に必ず実行）

`--scope` の値にかかわらず、本フェーズは常に実行する。

```bash
claude plugin marketplace update
```

このコマンドは Claude Code が内部で各マーケットプレイスのソース（`github` / `git` / `path`）に
応じた更新処理を行う。手動の `git fetch` / `git reset --hard` は **不要かつ実行禁止**。

#### B-1. 結果判定

XR-2（タイムアウト）と XR-3（出力サニタイズ）を適用する。

| exit code + 出力 | 判定 | 備考 |
|------------------|------|------|
| exit 0 + 出力に `Failed:` / `Error:` 行なし | 全 OK | 何も問題なし |
| exit 0 + 出力に `Failed:` / `Error:` 行あり | 部分失敗 | 該当行から MP 名を抽出（XR-3 サニタイズ後）。Phase C 以降は **警告付き継続** |
| exit 0 + 出力解析で MP 名抽出不能 | Unknown（要手動確認） | Phase F に Unknown 区分で残す |
| exit 非 0 | 全体失敗 | Phase C 以降は **警告付き継続**（CLI が古いインデックスでプラグイン更新を試みる可能性のため停止しない） |

CLI が将来 `--output json` を提供した場合、JSON モードへ切り替える拡張ポイントとしてこの箇所を残す。

### Phase C: User スコープのプラグイン更新

`--scope` が `user` または未指定の場合のみ実行（Phase B は別途常時実行済み）。
XR-1 / XR-2 / XR-3 を適用する。

User スコープの (plugin-name, marketplace-name) ごとに以下を実行:

```bash
claude plugin update <plugin-name>@<marketplace-name> --scope user
```

#### C-1. 結果分類（exit code 一次・出力解析は補助）

| exit code + 出力 | 結果分類 |
|------------------|---------|
| exit 0 + `updated` 相当 | Updated |
| exit 0 + `up-to-date` / `already latest` 相当 | No change |
| exit 0 + `not found` / `no such plugin` 相当 | Missing（exit 0 で not-found を返す CLI 実装に対応） |
| exit 非 0 + `not found` / `no such plugin` 相当 | Missing |
| exit 非 0 + 上記以外（ネットワーク・認証等） | Failed |
| exit 0 + いずれの相当文字列も検出不能 | Unknown（要手動確認） |

### Phase D: Project スコープのプラグイン更新

`--scope` が `project` または未指定、かつ git リポジトリ配下のときのみ実行。
処理内容は Phase C と同等で `--scope project` を指定する。**XR-1 / XR-2 / XR-3 を適用**。

### Phase E: Local スコープのプラグイン更新

`--scope` が `local` または未指定、かつ git リポジトリ配下のときのみ実行。
処理内容は Phase C と同等で `--scope local` を指定する。**XR-1 / XR-2 / XR-3 を適用**。

### Phase F: 結果報告

すべての更新処理を完了した時点で、以下の構造で **必ず結果報告** を提示する。
変数表記の `<count>` 等は Claude が実行時に実際の値に置き換える。

#### F-0. CLI 出力のサニタイズ（XR-3 の実装）

Phase F-2 / F-3 / G-2 で CLI 出力を表示する際は事前に以下のサニタイズを必ず適用する。
正規表現は CLI 出力の **値部分** に対して適用し、プラグイン名への誤適用は副作用として許容する。

| パターン | 置換後 | 備考 |
|---------|-------|------|
| `(?i)(token\|password\|secret\|authorization\|bearer\|x-api-key)[:=]\s*\S+` | `<key>=***REDACTED***` | 汎用 key=value |
| `https?://[^/\s]+:[^@\s]+@` | `https://***@` | URL 埋め込み認証 |
| `ghp_[A-Za-z0-9]{36,}` / `github_pat_[A-Za-z0-9_]{82,}` / `gho_[A-Za-z0-9]{36,}` / `ghs_[A-Za-z0-9]{36,}` / `ghu_[A-Za-z0-9]{36,}` | `***GITHUB_TOKEN***` | GitHub Personal Access Token |
| `glpat-[A-Za-z0-9_-]{20,}` | `***GITLAB_TOKEN***` | GitLab Personal Access Token |
| `AKIA[0-9A-Z]{16}` / `ASIA[0-9A-Z]{16}` | `***AWS_KEY_ID***` | AWS アクセスキー ID |
| `xox[baprs]-[A-Za-z0-9-]{10,}` | `***SLACK_TOKEN***` | Slack トークン |
| `eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}` | `***JWT***` | JWT |
| `/[\w./-]+\.pem`、`id_rsa`、`id_ed25519` 等 | `<ssh-key-path>` | SSH 鍵パス |
| `C:\\Users\\[^\\]+` / `/Users/[^/]+` / `/home/[^/]+` | `<user-home>` | ローカルパス内のユーザ名 |

**デフォルトはマスク優先**: 上記いずれにも合致しない長さ 30 字以上の `[A-Za-z0-9_\-]+` 連続トークンが
URL 等の文脈外で出現した場合は `***POSSIBLE_SECRET***` でマスクする（過剰サニタイズ容認）。

サニタイズ済み URL は誤展開を避けるため `<>` を文字参照化（`&lt;` / `&gt;`）する。

#### F-1. サマリ

```markdown
## 更新結果サマリ

| 区分 | 成功 | 変更なし | スキップ | 失敗 | Unknown |
|-----|-----|---------|---------|-----|---------|
| マーケットプレイス | <count> | <count> | <count> | <count> | <count> |
| User プラグイン | <count> | <count> | <count> | <count> | <count> |
| Project プラグイン | <count> | <count> | <count> | <count> | <count> |
| Local プラグイン | <count> | <count> | <count> | <count> | <count> |
```

Unknown 件数が **総件数の 20% を超える** 場合は明示的な警告メッセージを併記する:

```text
警告: Unknown 件数が全体の 20% を超えています。CLI 出力フォーマットが変わった可能性があるため、
F-2/F-3 の備考列を確認し、必要なら個別に手動更新してください。
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
  再起動前に以下を必ず実施してください:

  ```text
  claude plugin show <plugin>@<marketplace>
  ```

  特に `hooks` セクションが新規追加・変更されている場合、次回起動時に自動実行されます。
- Missing と判定されたエントリは `enabledPlugins` から除外することを検討（マーケットプレイスから消失）
- 更新後に問題が発覚した場合のロールバックは README の「ロールバック手順」セクションを参照
- （失敗があれば）次のリトライ・スキップ確認に応答する
```

### Phase G: 失敗対応の確認（失敗ありの場合のみ）

Phase F の結果報告後、**失敗が 1 件以上ある場合** は `AskUserQuestion` で以下を確認する。
失敗総数 `<N>` の定義は「Failed + Missing の合計」（Unknown は要手動確認のため除外）。
内訳には Phase B と Phase C〜E の失敗件数を入れる。

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

失敗エントリ数（Failed + Missing。Unknown は除外）が **5 件以下** の場合のみ各エントリについて確認する:

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

#### G-3. リトライ実行（範囲限定・XR-1/XR-2/XR-3/XR-4 を適用）

リトライは失敗種別に応じて **必要最小限のフェーズのみ** 再実行する。

| 失敗種別 | 再実行範囲 |
|---------|-----------|
| マーケットプレイス失敗 | **現状は全件リトライにフォールバック**（`claude plugin marketplace update <name>` 形式の引数指定サポートが CLI で確認できないため）。CLI が個別指定をサポートした際にこの箇所を更新する |
| プラグイン更新失敗（C/D/E 由来） | `claude plugin update <plugin>@<marketplace> --scope <scope>` を当該エントリのみ実行 |

XR-4 によりリトライは元の失敗集合に対し最大 1 回。リトライ中の新規失敗は記録のみ。

同一マーケットプレイスで連続 3 件以上のプラグイン更新失敗が続いた場合は、
当該マーケットプレイスの残エントリを自動 Skip（サーキットブレーカー）として時間浪費を抑制する。

#### G-4. リトライ完了後の最終報告（追記出力）

リトライ完了後、Phase F のサマリ・詳細テーブルを **同一フォーマットで再度出力** する
（チャット UI では前の出力を上書きできないため、新たなセクションとして追記）。
追記版が最終結果として確定する。新規失敗が増えた場合も同テーブル内に反映する。

## --dry-run モード時の挙動

`--dry-run` 指定時は **実際の更新コマンドを一切実行せず**、以下のみ提示する。

- Phase A の対象収集は通常通り実行（Read ツールで `settings.json` 系を読み込み、`claude plugin marketplace list` を実行。
  `marketplace list` はキャッシュ参照のみで更新通信を行わないことが期待されるが、CLI バージョンにより異なる場合がある）
- Phase A-1 / A-2 の検証も実行
- Phase B / C / D / E の代わりに、実行予定の CLI コマンド一覧を Phase F と同形式のテーブルで表示
  - 「結果」列の代わりに「実行予定コマンド」列を表示
- Phase F-4 / G はスキップ

**重要な制約**: `--dry-run` は **実行予定のコマンド一覧** のみを提示します。
**各プラグインの変更内容（新規 hooks / MCP / agents の追加）は確認しません**。
変更内容の確認には実行後 `claude plugin show <plugin>@<marketplace>` を別途実行する必要があります。

`--scope` と組み合わせた場合（例: `--dry-run --scope user`）は、指定スコープに限定したプレビューを表示。

## 注意事項

- 本コマンドは Claude Code 公式 CLI に処理を委譲するため、**ローカル変更の意図しない破壊や
  ブランチ強制移動は発生しない**（CLI 内部のロック制御・状態管理に依存）。
- スコープ別更新で同一プラグインを複数回処理しても、CLI が冪等性を保証する。
- プライベートリポジトリのマーケットプレイスは Git credential helper / SSH キーの設定が前提。
  認証エラー時の詳細は CLI 出力に依存する（XR-3 サニタイズで認証情報を伏せる）。
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

- [`../references/architecture-decisions.md`](../references/architecture-decisions.md) — プラグイン固有 ADR
- グローバルルール `~/.claude/rules/claude/plugin-auto-update.md`（自動更新ポリシー）
- `extension-toolkit:marketplace-toolkit`（マーケットプレイス本体管理）
- `extension-toolkit:marketplace-publisher`（マーケットプレイスへの公開）
