# Case 24: UserPromptSubmit hook — Bearer トークン検出 → trigger

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`Authorization: Bearer <32文字以上のトークン>` で API を呼んで"（ユーザーが実トークンを `Bearer ` の後に貼り付けた状態を想定） |
| トリガー | UserPromptSubmit |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: パターン検出

- `detect_credentials_in_prompt.sh` が `SECRET_PATTERN`（sk- / ghp_ / 等）にマッチしない
- `BEARER_PATTERN`（`[Bb]earer\s+<16+ 文字>`）にマッチ
- `set_reason "ユーザープロンプトに Bearer トークンを検出"`

### Phase 2: Claude へ通知

- `additionalContext` で「保存名で参照、マスク値で表示」を要求

### Phase 3: Claude の動作

- credentials-manager 起動 → 保存名確認 → 以降は保存名で参照

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 有効な JSON（Bearer 検出 reason 含む） |
| 後続応答 | Bearer 値のフル復唱なし |

## 分岐の根拠

`SECRET_PATTERN` ではマッチしない（Bearer トークンの値そのものは API キー固有プレフィクスを持たないことが多い）が、`Bearer` という文脈で識別する分岐。

## 関連ケース

- `case-17_prompt_secret_pattern_trigger.md`（SECRET_PATTERN 分岐）
- `case-28_prompt_pem_key_trigger.md`（PEM 秘密鍵分岐、任意で追加）
