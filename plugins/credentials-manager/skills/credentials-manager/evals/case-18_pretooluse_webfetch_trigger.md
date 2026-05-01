# Case 18: PreToolUse hook — WebFetch 呼び出し → trigger

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) | `{"tool_name":"WebFetch","tool_input":{"url":"https://api.openai.com/v1/models","prompt":"get models"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `preempt_credentials_check.sh` が `tool_name` を抽出 → `WebFetch`
- `WebFetch | WebSearch` 分岐に該当 → 常に対象

### Phase 2: Claude へ通知

- `additionalContext` で「外部 URL アクセスツール (WebFetch) の呼び出し。実行前に credentials-manager で対象 URL/ドメインの保存済み認証情報を必ず照合してください」と通知

### Phase 3: Claude の動作

- 通知を受けて credentials-manager スキルを最優先で起動
- 対象 URL `https://api.openai.com/...` のドメインで自動マッチ
- マッチ件数に応じた挙動（case-04 / case-05 / case-06 と同じ）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 有効な JSON（`additionalContext` 含む） |
| 終了コード | 0 |

## 分岐の根拠

`WebFetch` ツール常時 trigger 分岐（最も高頻度な発火点）。

## 関連ケース

- `case-04_auto_match_single.md`（trigger 後の URL 自動マッチ）
- `case-26_pretooluse_mcp_trigger.md`（同じ常時 trigger カテゴリで MCP）
