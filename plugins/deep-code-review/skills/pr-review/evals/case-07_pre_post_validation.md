# case-07 投稿前バリデーションチェックリスト

Step 7 の投稿前バリデーション（PATH/ESCAPE/SANITIZE/TEMPLATE の 4 項目）が全項目通過するケース。署名は connector が投稿前に自動付加するため pr-review 側では付加・検証しない。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "PR #456 をレビューして"（Azure DevOps） |
| モード | 対話 |

## 分岐の根拠

SKILL.md Step 7 投稿前バリデーションチェックリスト（`${CLAUDE_SKILL_DIR}/references/pre-post-validation.md`）。各コメントの API 投稿前に **4 項目（PATH / ESCAPE / SANITIZE / TEMPLATE）** を通過することが必須。署名（SIGNATURE）は connector が自動付加する責務のため pr-review 側の検証項目に含めない。

## 期待動作

- [PATH] threadContext.filePath が `/` 始まりのリポジトリルート相対パスである
- [PATH] jq への値渡しに --rawfile を使用している（--arg 禁止）
- [PATH] filePath に `C:\` や `C:/Program Files/` が含まれない
- [ESCAPE] 本文中の `#<数字>` が `\#` でエスケープされている
- [ESCAPE] 本文中の `@<英数字>` が `\@` でエスケープされている
- [SANITIZE] comment-sanitization.md セクション 5.6 チェックリスト通過済み
- [TEMPLATE] コメント本文が comment-templates.md のテンプレートから組み立てられている
- [署名は検証対象外] 投稿本文の末尾に署名を含めない（connector が投稿前に自動付加するため pr-review は付加・検証しない。pre-post-validation.md [SIGNATURE]）

## 関連ケース

- case-08: バリデーション失敗時（投稿スキップ）
- case-09: テンプレート駆動方式
