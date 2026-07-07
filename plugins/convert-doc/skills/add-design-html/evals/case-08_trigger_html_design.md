# Case 08: トリガー判定

## 入力

以下のような自然言語依頼。

- 「HTML 資料の新しいデザインテーマを作って」
- 「ドキュメントの見た目のバリエーションを増やしたい」
- 「convert-html にダークモードのデザインを追加して」

## 期待動作

1. `add-design-html` スキルが起動する（`convert-html` や `add-design-pptx` ではなく）
2. 対話モードでデザイン名・コンセプトの確定に進む

## 起動しないべき入力

| 入力 | 正しい起動先 |
|------|------------|
| 「この MD を HTML にして」 | `convert-html` |
| 「PPTX のテーマを追加して」 | `add-design-pptx` |
| 「warm-paper デザインで HTML 変換して」 | `convert-html`（CSS 選択） |
| 「PDF に変換して」 | `convert-pdf` |

## 期待出力

- `add-design-html` の実行フロー（要件確定）への遷移。変換や別スキルの起動は発生しない

## 分岐の根拠

`SKILL.md` frontmatter description の SKIP 条件、「トリガー条件」。

## 関連ケース

- [case-01_interactive_css_only.md](case-01_interactive_css_only.md): 起動後の基本フロー
