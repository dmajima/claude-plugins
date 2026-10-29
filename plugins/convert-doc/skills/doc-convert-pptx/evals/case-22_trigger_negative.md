# Case 22: トリガー判定（起動しないべき入力）

## 入力

以下のような自然言語依頼。

- 「この PPTX を Markdown にして」（入力が PPTX）
- 「この MD を HTML にして」（出力が HTML）
- 「設計書を PDF 化して」（出力が PDF）
- 「PPTX のデザインテーマを追加して」（テーマの新規作成）

## 期待動作

1. `doc-convert-pptx` スキルは **起動しない**
2. それぞれ正しいスキルへルーティングされる

## 起動しないべき入力と正しい起動先

| 入力 | 正しい起動先 |
|------|------------|
| 「この PPTX を Markdown にして」 | `doc-convert-from-pptx` |
| 「この MD を HTML にして」 | `doc-convert-html` |
| 「設計書を PDF 化して」 | `doc-convert-pdf` |
| 「PPTX のデザインテーマを追加して」 | `doc-add-design-pptx` |

## 期待出力

- `doc-convert-pptx` の実行フロー（ワークディレクトリ作成・venv 構築）が開始されない

## 分岐の根拠

`SKILL.md`「このスキルを起動しないケース」:
> - HTML / PDF への変換依頼（`doc-convert-html` / `doc-convert-pdf` へルーティング）
> - 入力が PPTX（PPTX → Markdown は `doc-convert-from-pptx` へルーティング）
> - 新しいデザインテーマの追加依頼（`doc-add-design-pptx` へルーティング）

## 関連ケース

- [case-09_trigger_md_to_pptx.md](case-09_trigger_md_to_pptx.md): 起動すべき入力（正例）
