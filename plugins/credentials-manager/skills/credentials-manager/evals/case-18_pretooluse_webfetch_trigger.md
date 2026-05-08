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

- `additionalContext` で「外部 URL アクセスツール (WebFetch) の呼び出し。`credentials-reader` を最優先起動して保存済み認証情報を照合してください（1件→自動適用 / 複数件→選択 / 0件→保有有無確認）。書き込みは `credentials-manager` に引き継ぎます」と通知

### Phase 3: Claude の動作

- 通知を受けて **`credentials-reader`** スキルを最優先で起動
- 対象 URL `https://api.openai.com/...` のドメインで自動マッチ
- マッチ件数に応じた挙動（reader case-01 / case-02 / case-03 と同じ）
- 0 件マッチで保存承諾された場合のみ `credentials-manager` に引き継ぎ

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 有効な JSON（`additionalContext` 含む） |
| 終了コード | 0 |

## 分岐の根拠

`WebFetch` ツール常時 trigger 分岐（最も高頻度な発火点）。v2.0.0 では reader 起動指示に統一（hooks 軽量化）。

## 関連ケース

- `credentials-reader:case-01_auto_match_single.md`（trigger 後の URL 自動マッチ）
- `case-22_pretooluse_read_env_example_noop.md`（同じ常時 trigger カテゴリで no-op 境界）
