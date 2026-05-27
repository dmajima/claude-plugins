# minutes-docx

構造化議事録データ（minutes.json）を python-docx で Word ファイルに変換するスキル。

## このドキュメントについて

本ファイルは人間向けリファレンスであり、Claude の動作では使用されない。

## 使い方

minutes-composer で構造データ作成後、Word 出力を依頼する。

```
議事録を Word で出力して
```

スタイル定義済みの docx テンプレート（Meiryo ベース）に JSON データを流し込んで生成する。

## テンプレートのスタイル

| スタイル名 | 用途 | フォント/サイズ |
|-----------|------|--------------|
| Title | 会議タイトル | Meiryo / 18pt |
| Heading 1 | セクション見出し | Meiryo / 14pt |
| Heading 2 | 議題見出し | Meiryo / 12pt |
| Normal | 本文 | Meiryo / 10.5pt |

## ファイル構成

```
minutes-docx/
├── SKILL.md
├── README.md
├── assets/
│   └── template/
│       └── minutes-template.docx  # Word テンプレート
├── references/
│   └── procedures.md              # 生成手順
└── scripts/
    └── output/
        ├── generate_docx.py       # docx 生成スクリプト
        └── create_template.py     # テンプレート作成スクリプト
```
