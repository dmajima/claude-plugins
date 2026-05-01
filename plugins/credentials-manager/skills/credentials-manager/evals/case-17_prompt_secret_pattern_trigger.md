# Case 17: UserPromptSubmit hook — シークレットパターン検出 → 保存提案

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "OpenAI のキーは sk-abcdefghijklmnopqrstuvwxyz0123456789 を使ってください" |
| トリガー | UserPromptSubmit |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: パターン検出

- `detect_credentials_in_prompt.sh` が `prompt` フィールドから `sk-...` パターンを検出
- `SECRET_PATTERN` の正規表現にマッチ

### Phase 2: Claude へ通知

- `hookSpecificOutput.additionalContext` で「ユーザープロンプトに認証情報パターンを検出。応答ではこの値を平文で復唱せず、credentials-manager で保存提案 → 保存名で参照 → マスク値で表示」と通知
- `suppressOutput: true` で UI 上はサイレント

### Phase 3: Claude の動作

- 通知を受けて credentials-manager スキルを最優先で起動
- 保存名を `AskUserQuestion` で確認（例: `openai-api-key`）
- 保存後、応答中ではマスク値（`sk-a****6789`）のみで言及

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 有効な JSON（`additionalContext` 含む） |
| 後続応答 | フル値の復唱なし、マスク値のみ |
| 終了コード | 0 |

## 分岐の根拠

`SECRET_PATTERN` 系（sk-* / ghp_* / xoxb-* / AKIA / AIza / glpat- / JWT）で trigger する分岐。

## 関連ケース

- `case-03_proactive_detect.md`（スキル本体のプロアクティブ検出）
- `case-24_prompt_bearer_trigger.md`（Bearer 分岐）
- `case-29_prompt_no_secret_noop.md`（任意の追加で対応する no-op）
