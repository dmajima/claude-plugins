# Case 38: PreToolUse hook — PowerShell + 認証情報と無関係な環境変数の設定 → no-op

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) | `{"tool_name":"PowerShell","tool_input":{"command":"$env:MSYS_NO_PATHCONV = 1; Get-Location"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `PowerShell`、`tool_input.command` 抽出

### Phase 2: コマンド解析

- `$env:NAME = ...` 形式の代入だが、変数名 `MSYS_NO_PATHCONV` は認証情報キーワードを含まない
- `Get-Location` も外部通信コマンドではない
- `REASON` が空のまま `exit 0`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 空 |
| 終了コード | 0 |
| Claude のコンテキスト | 追加されない |

## 分岐の根拠

`case-29`（Bash の `export MSYS_NO_PATHCONV=1`）の PowerShell 版。環境変数の設定であることだけを
条件にすると、無関係な設定のたびに通知が出るため、変数名に認証情報キーワードを含むことを必須にしている。

キーワードは変数名への部分一致で照合するため、`$env:GIT_AUTHOR_NAME`（`AUTH`）や `$env:API_BASE_URL`（`API`）は
認証情報と無関係でも trigger する（既知の誤検出。Bash の `export` でも同じ）。

## 関連ケース

- `case-29_pretooluse_bash_env_noncredential_noop.md`（同じ境界で Bash 側）
- `case-35_pretooluse_powershell_env_credential_trigger.md`（対比：trigger するケース）
