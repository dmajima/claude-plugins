# case-30 U16 回帰指摘の PR インラインコメント伝播（U16 propagation）

観点別スキルが検出し code-review オーケストレーターが Finding ID を採番した U16 回帰指摘（防御コード削除の回帰）を、pr-review が PR インラインコメントに伝播して該当箇所に投稿する分岐を検証する。pr-review 自身は U16 を再検出せず、委譲結果の指摘をそのまま伝播する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "https://github.com/example/repo/pull/321 をレビューして"（GitHub・gh auth status 成功） |
| モード | 対話 |
| 前提 | Step 6 の code-review 委譲で返却された統合サマリに、リファクタ差分の削除側（`-` 行）で `[Authorize]` 属性 / `finally` のリソース解放が除去され再導入されていない U16 回帰指摘（例: CR-005 [High] 認可属性削除の回帰）が Finding ID・重要度・信頼度・該当箇所付きで含まれている |

## 分岐の根拠

SKILL.md Step 6（code-review へ委譲）→ Step 7（PR コメント投稿）、`${CLAUDE_SKILL_DIR}/references/comment-posting.md` セクション 7.0.1（インライン冒頭 `## [CR-NNN] [<致命度>] <タイトル>` の H2 見出し）・セクション 7.0.3（統合サマリの Finding ID ごとにインラインコメントを組み立て該当箇所へ 1 件ずつ投稿）、`${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` P21（インライン本文冒頭の Finding ID H2 表示）、および U16（`${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` セクション 2 / `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U16。matrix セクション 8 脚注により U16 は「コード差分を評価するスキル + それらを統合する code-review + pr-review 経由」に適用）。pr-review は U16 を自ら検出せず、委譲結果に含まれる U16 回帰指摘を伝播する立場である点が分岐の要点。

## 期待動作

- Step 6 で code-review オーケストレーターへ委譲し、返却された統合サマリに U16 回帰指摘（防御コード削除の回帰・CR-NNN 採番済み・重要度 / 信頼度 / 該当箇所付き）が含まれることを受領する（SKILL.md Step 6）
- pr-review は U16 判定を再実行せず、委譲結果の指摘をそのまま伝播する（comment-posting.md セクション 7.0.3。重要度・信頼度はオーケストレーター採用値を維持し再評価・降格しない）
- Step 7 で当該 U16 回帰指摘を PR インラインコメントとして、防御コードが削除された該当箇所（`filePath` + 変更後の行範囲 `rightFileStart`/`rightFileEnd`。純削除の場合は隣接する変更後行）にアンカーして投稿する（comment-posting.md セクション 7.1.1 / 7.2.1）
- インラインコメント本文の冒頭が `## [CR-NNN] [<致命度>] <タイトル>` の H2 見出しで始まり、本文で「削除側（`-` 行）の防御コードが追加側で再導入されていない回帰」であることと求める修正（防御の再導入）を伝える（P21 / comment-posting.md セクション 7.0.1）
- 該当コードの引用はコードフェンスで囲み、投稿前バリデーション 4 項目（PATH / ESCAPE / SANITIZE / TEMPLATE）を通過してから投稿する（SKILL.md Step 7 / pre-post-validation.md）
- サマリースレッドの Finding ID 目次に当該 U16 指摘を含め、投稿順序（インライン → 旧サマリー closed → 新サマリースレッド）を厳守する（P20 / P32 / comment-posting.md セクション 7.6）
- Step 7.4 で Finding ID → Thread ID マッピングを保存し、Step 8 完了報告に Finding ID → コメント ID の対応を含める（P22 / P23）
- PR 外リソースへの書き込みは行わない（U7）

## 関連ケース

- case-01: GitHub PR の初回標準レビュー（インライン + サマリー投稿の基本フロー）
- case-09: テンプレート駆動のコメント組み立て（インライン冒頭 P21 H2 見出し）
