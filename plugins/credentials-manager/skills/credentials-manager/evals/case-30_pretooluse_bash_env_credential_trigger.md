# Case 30: PreToolUse hook — Bash + 認証情報らしい環境変数の export → trigger

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) | `{"tool_name":"Bash","tool_input":{"command":"export GITHUB_TOKEN=<dummy>"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `Bash`、`tool_input.command` 抽出

### Phase 2: コマンド解析

- 変数名 `GITHUB_TOKEN` が認証情報キーワード `TOKEN` を含むため、環境変数 export パターンにマッチする
- `REASON` = `Bash で認証情報らしい環境変数を設定`

### Phase 3: 出力

- `additionalContext` で credentials-reader の最優先起動を指示する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | `hookSpecificOutput.additionalContext` に `Bash で認証情報らしい環境変数を設定` と credentials-reader の起動指示を含む JSON |
| 終了コード | 0 |
| Claude のコンテキスト | credentials-reader の起動指示が追加される |

## 分岐の根拠

検出漏れ防止の境界ケース。キーワードは変数名の先頭・途中・末尾のいずれにあっても検出する
（`TOKEN` / `OPENAI_API_KEY` / `MY_SESSION_ID` / `set DB_PASSWORD=...` も同様に trigger）。

## 関連ケース

- `case-29_pretooluse_bash_env_noncredential_noop.md`（対比：no-op のケース）
- `case-19_pretooluse_bash_curl_trigger.md`（同じ trigger カテゴリ）
