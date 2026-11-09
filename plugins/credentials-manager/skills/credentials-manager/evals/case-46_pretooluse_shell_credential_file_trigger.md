# Case 46: PreToolUse hook — シェルで認証情報系ファイルを操作 → trigger

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) 例 1 | `{"tool_name":"Bash","tool_input":{"command":"cat .env"}}` |
| stdin (Claude → hook) 例 2 | `{"tool_name":"PowerShell","tool_input":{"command":"Get-Content $HOME\\.aws\\credentials"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `Bash` / `PowerShell`、`tool_input.command` 抽出

### Phase 2: コマンド解析

- 外部通信・環境変数の設定・シークレットパターンには一致しない
- コマンドが認証情報系ファイルの手掛かりの語（`.env` / `.aws` 等）を含むため、空白・区切り・括弧・引用符・`=` でトークンに分け、
  ファイル系ツールと同じ規則（`credential_file_reason`）で各トークンを判定する
- 例 1: `.env` → `REASON` = `Bash で環境変数定義ファイル (.env) を操作`
- 例 2: `$HOME\.aws\credentials` → `REASON` = `PowerShell で AWS 認証情報ファイル (~/.aws/...) を操作`

### Phase 3: Claude へ通知

- `additionalContext` で credentials-reader の最優先起動と、値をマスクして扱うことを指示する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | `hookSpecificOutput.additionalContext` に上記の理由文を含む JSON |
| 終了コード | 0 |

## 分岐の根拠

`Read` ツールで `.env` を読むと通知されるのに、シェルの `cat .env` / `Get-Content .env` では通知されないと、同じ操作の扱いが
経路によって食い違う。操作の種類（読み取り・コピー・権限変更・`git add`）は問わず、認証情報系ファイルを指すトークンがあれば通知する。
`.env*` / `*.pem` のようなワイルドカードと、`~/.ssh` / `~/.aws` などのディレクトリそのものも対象にする。

## 関連ケース

- `case-21_pretooluse_read_env_trigger.md`（同じファイルを Read ツールで読むケース）
- `case-47_pretooluse_shell_extension_like_word_noop.md`（対比：no-op のケース）
