# Case 53: PreToolUse hook — シェルのコマンドに Basic 認証ヘッダ → trigger

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) | `{"tool_name":"Bash","tool_input":{"command":"echo \"Authorization: Basic <base64 で 16 文字以上>\""}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `Bash`、`tool_input.command` 抽出
- 外部通信 CLI・環境変数の設定には該当しない

### Phase 2: パターン照合

- UserPromptSubmit のフックと共通のパターン（`lib/credential_patterns.sh` の `CRED_BASIC_PATTERN`）で照合する
- `Basic` の後に空白と 16 文字以上の base64 文字が続く → `REASON` = `Bash コマンドに Basic 認証ヘッダらしい文字列を検出`
  （英字で始まる語句の前には空白を入れる）

### Phase 3: Claude へ通知

- `additionalContext` で credentials-reader の最優先起動と、フル値を復唱せずマスクすることを指示する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | `hookSpecificOutput.additionalContext` に上記の理由文を含む JSON |
| 終了コード | 0 |

## 分岐の根拠

ルールテンプレートの 1.2 は Basic 認証ヘッダを検出対象に挙げている。Basic 認証の値は `user:password` を base64 にしただけで、
復号すればパスワードが分かるため、トークンと同じく値を復唱せずに扱う。
`Basic` の直後に英数字だけの長い語（16 文字以上）が続く場合は、認証スキーム名のような識別子でも通知される（既知の誤検出）。

## 関連ケース

- `case-45_pretooluse_pem_private_key_trigger.md`（同じ共通パターンの PEM 秘密鍵）
- `case-36_pretooluse_powershell_secret_pattern_trigger.md`（同じコマンドの照合で既知のトークン形式）
