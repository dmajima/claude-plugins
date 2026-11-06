# Case 29: PreToolUse hook — Bash + 認証情報と無関係な環境変数の export → no-op

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) | `{"tool_name":"Bash","tool_input":{"command":"export MSYS_NO_PATHCONV=1; ls"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `Bash`、`tool_input.command` 抽出

### Phase 2: コマンド解析

- `ls` は外部通信コマンドリストに含まれない
- `export MSYS_NO_PATHCONV=1` は変数名に認証情報キーワード（`TOKEN` / `KEY` / `SECRET` / `PASSWORD` / `PASSWD` / `API` / `AUTH` / `CREDENTIAL` / `SESSION` / `BEARER` / `PRIVATE`）を含まないため、環境変数 export パターンにマッチしない
- シークレットパターンにもマッチしない
- `REASON` が空のまま `exit 0`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 空 |
| 終了コード | 0 |
| Claude のコンテキスト | 追加されない |

## 分岐の根拠

過検出抑制の境界ケース。2.1.2 までは変数名のキーワード部分が任意（`(...)?`）だったため、
`export MSYS_NO_PATHCONV=1` や `export PATH=...` のような無関係な export / set まで
「認証情報らしい環境変数を設定」として検出していた。
このケースが trigger に変わった場合は、キーワード部分が再び任意になっていないかを確認する。

## 関連ケース

- `case-30_pretooluse_bash_env_credential_trigger.md`（対比：trigger するケース）
- `case-20_pretooluse_bash_local_noop.md`（同じ no-op カテゴリ）
