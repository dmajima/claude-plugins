# Case 40: PreToolUse hook — PowerShell + 認証情報らしい環境変数の参照 → no-op

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) | `{"tool_name":"PowerShell","tool_input":{"command":"Write-Output $env:GITHUB_TOKEN.Length"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `PowerShell`、`tool_input.command` 抽出

### Phase 2: コマンド解析

- 変数名 `GITHUB_TOKEN` は認証情報キーワード `TOKEN` を含むが、`$env:GITHUB_TOKEN` の後に `=` / `+=` が続かないため、設定ではなく参照と判定する
- 外部通信コマンド・シークレットパターンにも一致せず、`REASON` が空のまま `exit 0`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 空 |
| 終了コード | 0 |
| Claude のコンテキスト | 追加されない |

## 分岐の根拠

環境変数の設定と参照の境界ケース。設定（`$env:NAME = ...`）だけを検出し、値の有無の確認や長さの表示のような参照では通知しない。
`Write-Output $env:PATH` / `Get-ChildItem Env:` / 複数行のコマンドで 2 行目に `Get-Item Env:GITHUB_TOKEN` があるだけの場合も同様に no-op
（設定の照合は改行をまたがない）。

値そのものを表示する参照（`Write-Output $env:GITHUB_TOKEN`）も通知しない。値の表示を防ぐ検査は本フックの範囲外である。

## 関連ケース

- `case-35_pretooluse_powershell_env_credential_trigger.md`（対比：設定で trigger するケース）
- `case-38_pretooluse_powershell_env_noncredential_noop.md`（無関係な環境変数の設定で no-op）
