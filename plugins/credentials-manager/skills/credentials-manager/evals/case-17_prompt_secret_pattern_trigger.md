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

- `hookSpecificOutput.additionalContext` で「ユーザープロンプトに認証情報パターンを検出。フル値を復唱せずマスク表示（先頭4+****+末尾4、8文字以下は全マスク****）してください。`credentials-reader` を最優先起動して既存照合 + 保存提案を行い、ユーザ承諾時のみ `credentials-manager` に引き継いで保存します」と通知
- `suppressOutput: true` で UI 上はサイレント

### Phase 3: Claude の動作

- 通知を受けて **`credentials-reader`** スキルを最優先で起動
- まず保存済みかどうかを照合 → 既存があればマスク値で確認
- 既存になければユーザに保存提案（`AskUserQuestion`）
- 承諾された場合のみ **`credentials-manager`** に引き継ぎ、保存名を AskUserQuestion で確認（例: `openai-api-key`）
- 保存後、応答中ではマスク値（`sk-a****6789`）のみで言及

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 有効な JSON（`additionalContext` 含む） |
| 後続応答 | フル値の復唱なし、マスク値のみ |
| 終了コード | 0 |

## 分岐の根拠

`SECRET_PATTERN` 系（sk-* / ghp_* / xoxb-* / AKIA / AIza / glpat- / JWT）で trigger する分岐。v2.0.0 では reader 起動指示に統一されている（hooks 軽量化）。

## 関連ケース

- `credentials-reader:case-07_proactive_detect.md`（reader 側のプロアクティブ検出フロー）
- `case-24_prompt_bearer_trigger.md`（Bearer 分岐）
- `case-28_handoff_from_reader.md`（reader 引き継ぎ受け入れ）
