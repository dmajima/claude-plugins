# case-25 悪性コンテンツのサニタイズ変換（P6 / P7 / P8）

レビュー指摘の該当コードに XSS ペイロード・トラッキング画像・機密文字列・自動リンク化対象が含まれる場合の、投稿前サニタイズの実変換結果を検証する。手続き確認ではなく変換内容の正しさを見る。

## 入力

| 項目 | 内容 |
|-----|------|
| 想定シナリオ | 差分コードに (a) `<script>alert(1)</script>` / `<img src=x onerror=...>` / (b) 外部トラッキング画像 Markdown `![](https://track.example/pixel.gif)` / (c) `Bearer eyJ...` 風の機密文字列 / (d) `#123`・`@user`・`!important` 等の自動リンク化対象 が含まれる |
| モード | 対話（PR コメント投稿を伴う） |

## 分岐の根拠

references/skill-rules-matrix.md P6（コメント本文サニタイズ）・P7（予約文字エスケープ）・P8（投稿前チェックリスト通過）、`${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` セクション 3〜5、`${CLAUDE_SKILL_DIR}/references/pre-post-validation.md`。

## 期待動作

- (a) XSS: コード引用はコードフェンス（```）で囲み、`<script>` / `<img onerror=>` は実行されない引用として表示する。HTML 文脈（`<details>` 内）では `<` `>` `&` を HTML エスケープする（comment-sanitization.md セクション 3）
- (b) トラッキング画像: 外部画像 Markdown（`![](...)`）と `<img>` タグを削除する（自動読み込みによるトラッキングを防ぐ。comment-sanitization.md セクション 3）
- (c) 機密文字列: `Bearer eyJ...`（JWT）・PAT・AWS/GCP/Slack トークン等を伏字化する（先頭数文字 + `***`。疑わしい場合は伏字側に倒す。comment-sanitization.md セクション 4）
- (d) 予約文字: 自動リンク化対象の `#` `@` `!` を `\#` `\@` `\!` でエスケープ、または明示リンク化する（comment-sanitization.md セクション 5.5・P7）
- 危険スキームリンク（`javascript:` / `data:` / `vbscript:` / `file:`）を剥離する
- 上記変換をすべて適用し、投稿前チェックリスト（pre-post-validation.md の PATH / ESCAPE / SANITIZE / TEMPLATE）を全項目通過してから投稿する（P8）。未通過なら投稿しない

## 関連ケース

- case-07: 投稿前バリデーション 4 項目（PATH / ESCAPE / SANITIZE / TEMPLATE）の全通過（手続き）
- case-09: テンプレート駆動のコメント組み立て
