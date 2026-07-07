# Case 07: トリガー判定

## 入力

以下のような自然言語依頼。

- 「スライドの新しい配色テーマを作って」
- 「PowerPoint 用にダークテーマを追加したい」
- 「convert-pptx のデザインバリエーションを増やして」

## 期待動作

1. `add-design-pptx` スキルが起動する（`convert-pptx` や `add-design-html` ではなく）
2. 対話モードでデザイン名・コンセプトの確定に進む

## 起動しないべき入力

| 入力 | 正しい起動先 |
|------|------------|
| 「この MD をスライドにして」 | `convert-pptx` |
| 「HTML のデザインを追加して」 | `add-design-html` |
| 「テーマ ocean-blue でスライド変換して」 | `convert-pptx`（テーマ選択） |

## 期待出力

- `add-design-pptx` の実行フロー（要件確定）への遷移。変換や別スキルの起動は発生しない

## 分岐の根拠

`SKILL.md` frontmatter description の SKIP 条件、「トリガー条件」。

## 関連ケース

- [case-01_interactive_basic.md](case-01_interactive_basic.md): 起動後の基本フロー
