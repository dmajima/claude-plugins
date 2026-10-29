# Case 08: ダーク系テーマのコントラスト調整

## 入力

- ユーザー依頼: 「コードブロックが暗い背景のテーマにして」
- 例: `code_bg: #16213E` のみ指定された状態

## 期待動作

1. `code_bg` を暗色にする際、`theme-schema.md` のガイドラインに従い以下を連動調整する
   - `code_text` を明色（例: `#E8E8E8`）に
   - `code_border` を背景に馴染む色に
   - `syntax_palette` の全キーを暗背景で読める明色系に
2. デフォルトの `syntax_palette`（明背景前提の配色）を暗背景に残さない
3. サンプル変換の PPTX でコードブロックの可読性を確認できる状態で提示する

## 期待出力

- 暗背景でもトークン色が読めるテーマ JSON（検証 PASS）

## 分岐の根拠

`references/theme-schema.md`「syntax_palette」:
> `code_bg` を暗色にする場合は `syntax_palette` 全キーと `code_text` を明色系に揃えること（コントラスト確保）

## 関連ケース

- [case-03_schema_error_retry.md](case-03_schema_error_retry.md): スキーマエラーの修正
