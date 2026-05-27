# minutes-composer

会議の文字起こしとトピック要約から構造化議事録データ（JSON）を作成するスキル。

## このドキュメントについて

本ファイルは人間向けリファレンスであり、Claude の動作では使用されない。

## 使い方

ailead-fetcher または transcript-converter でデータ取得・変換後に自動的に呼び出される。

```
（ailead-fetcher 実行後）議事録を構成して
```

入力パターンにより処理フローが分岐する:
- ailead ソース: トピック要約を骨格に文字起こしと突合して構造化
- 汎用テキスト: 文字起こしからゼロベースで構造化

出力は `minutes.json`（構造化 JSON）。最終出力形式（docx 等）は下流スキルが担当。

## ファイル構成

```
minutes-composer/
├── SKILL.md
├── README.md
└── references/
    ├── schema/
    │   └── minutes-schema.md      # JSON スキーマ定義
    ├── steps/
    │   ├── ailead-flow.md         # ailead フロー手順
    │   └── generic-flow.md        # 汎用フロー手順
    └── template/
        └── minutes-template.md    # Markdown テンプレート（参考）
```
