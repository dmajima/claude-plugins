# Case 43: UserPromptSubmit hook — プロンプト中の PEM 形式の秘密鍵 → trigger

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「この鍵で接続して」の後に、PEM 形式の秘密鍵（先頭行が、ハイフン 5 個に挟まれた `BEGIN RSA PRIVATE KEY`）を貼り付けた状態を想定 |
| トリガー | UserPromptSubmit |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: 入力の解析

- 標準入力の JSON から `prompt` を取り出す

### Phase 2: パターン照合

- シークレット / Bearer / Basic のパターンには一致しない
- PEM の先頭行のパターン（`-----BEGIN` + 任意の種別 + `PRIVATE KEY-----`）に一致する
- `REASON` = `ユーザープロンプトに PEM 形式の秘密鍵を検出`

### Phase 3: Claude へ通知

- `additionalContext` で、フル値を復唱せずマスクすること・credentials-reader の最優先起動・承諾時のみ credentials-manager に引き継ぐことを指示する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | `hookSpecificOutput.additionalContext` に `ユーザープロンプトに PEM 形式の秘密鍵を検出` を含む JSON |
| 終了コード | 0 |

## 分岐の根拠

PEM のパターンは `-` で始まるため、`grep -E "<パターン>"` に渡すと grep がオプションと解釈してエラーで終了し、一致しない。
照合は bash 組み込みの正規表現で行う。回帰テストでは、先頭行を実行時に組み立てたダミーで検証する。

## 関連ケース

- `case-17_prompt_secret_pattern_trigger.md`（同じフックでシークレットパターン）
- `case-24_prompt_bearer_trigger.md`（同じフックで Bearer トークン）
