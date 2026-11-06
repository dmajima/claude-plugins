# Case 42: PreToolUse hook — 不正な入力 → no-op（フェイルオープン）

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) 例 1 | `{"tool_name":"PowerShell","tool_input":{}}`（`command` が無い） |
| stdin (Claude → hook) 例 2 | `{not json`（JSON として不正） |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: 入力の解析

- 例 1: `tool_name` は `PowerShell` だが `tool_input.command` が取れないため、シェル系の検査を行わない
- 例 2: `jq` が `tool_name` を取り出せないため、その時点で `exit 0`

### Phase 2: 終了

- いずれも `REASON` が空のまま、何も出力せずに `exit 0`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 空 |
| 終了コード | 0 |
| Claude のコンテキスト | 追加されない |

## 分岐の根拠

フックは念押しのための仕組みであり、入力が想定外でもツールの実行を妨げない（フェイルオープン）。
標準入力が空・空白のみの場合と、`jq` が無い環境でも同様に何も出力せずに `exit 0` する。
SessionStart フックの同種のケースは `case-25`。

## 関連ケース

- `case-25_session_start_missing_env_silent_exit.md`（SessionStart のフェイルオープン）
- `case-32_pretooluse_powershell_invoke_restmethod_trigger.md`（正常な PowerShell の入力）
