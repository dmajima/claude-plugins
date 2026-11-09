# Case 45: PreToolUse hook — Write のコンテンツに PEM 形式の秘密鍵 → trigger

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) 例 1 | `{"tool_name":"Write","tool_input":{"file_path":"/repo/id.txt","content":"<PEM の先頭行>\nMIIE..."}}`（先頭行は、ハイフン 5 個に挟まれた `BEGIN RSA PRIVATE KEY`） |
| stdin (Claude → hook) 例 2 | 例 1 の先頭行が PGP の秘密鍵の形（`PRIVATE KEY` の後に ` BLOCK` が続く）のもの |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `Write`、`tool_input` の文字列を抽出

### Phase 2: パターン照合

- UserPromptSubmit のフックと共通のパターン（`lib/credential_patterns.sh` の `CRED_PEM_PATTERN`）で照合する
- 例 1・例 2: PEM の先頭行に一致 → `REASON` = `Write のコンテンツに PEM 形式の秘密鍵を検出`

### Phase 3: Claude へ通知

- `additionalContext` で credentials-reader の最優先起動と、フル値を復唱せずマスクすることを指示する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | `hookSpecificOutput.additionalContext` に上記の理由文を含む JSON |
| 終了コード | 0 |

## 分岐の根拠

ルールテンプレートの 1.2 は PEM 秘密鍵を検出対象に挙げている。パターンを 2 つのフックで共有し、
PreToolUse でも同じ範囲を検出する（フックごとに定義すると検出範囲が食い違う）。
公開鍵（`PUBLIC KEY`）の先頭行は対象外。

## 関連ケース

- `case-43_prompt_pem_private_key_trigger.md`（同じ PEM のパターンで UserPromptSubmit 側）
- `case-53_pretooluse_basic_auth_trigger.md`（同じ共通パターンの Basic 認証ヘッダ）
- `case-23_pretooluse_write_secret_trigger.md`（同じコンテンツの照合でシークレットパターン）
