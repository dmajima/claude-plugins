# case-09 テンプレート駆動方式によるコメント組み立て

comment-templates.md のテンプレートからインラインコメント本文を組み立てて投稿するケース（署名は connector が投稿前に自動付加するため pr-review 本文には含めない）。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "PR #101 をレビューして"（GitHub） |
| モード | 対話 |

## 分岐の根拠

SKILL.md Step 7「コメント本文は comment-templates.md のテンプレートから組み立てる（署名セクションを除く）。静的文言の手書き再構成は禁止」。署名は connector が投稿前に自動付加する（`${CLAUDE_SKILL_DIR}/references/pre-post-validation.md` [SIGNATURE]）ため、pr-review は署名を組み立て・検証しない。

## 期待動作

- インラインコメント本文が `## [CR-NNN] [致命度] タイトル` の H2 見出しで始まる（P21）
- コメント本文が comment-templates.md のテンプレートから組み立てられている（TEMPLATE 項目・静的文言の手書き再構成をしていない）
- 投稿本文の末尾に署名を含めない（connector が投稿前に自動付加するため pr-review は署名を組み立てない）
- サマリースレッド本文もテンプレート駆動で組み立て、署名は connector に委譲する（pr-review 側で署名文字列を再構成しない）

## 関連ケース

- case-07: 投稿前バリデーション（TEMPLATE 項目を含む 4 項目チェック）
