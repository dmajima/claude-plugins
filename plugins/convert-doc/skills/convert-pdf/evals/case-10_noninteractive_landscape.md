# Case 10: 非対話モード（横向き PDF 指定）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "この Markdown を横向き PDF にして" |
| モード | 非対話 |
| 暗黙オプション | `--landscape` |

## 期待動作

- convert-pdf スキルが起動する
- 「横向き」の指示から `--landscape` オプションを適用する
- 入力 MD のパスが特定可能な場合はユーザー確認をスキップする
- convert-html 経由で中間 HTML を生成する
- Playwright Chromium で A4 横・背景色印刷ありの PDF を生成する

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | A4 横向き（landscape）の PDF ファイル（セッションフォルダ直下） |
| ページ設定 | landscape: true, printBackground: true |

## 分岐の根拠

SKILL.md の実行モード判定表でオプション指定による非対話相当の動作に該当。「横向き」の自然言語指示が `--landscape` フラグに変換され、縦/横のページ方向分岐で横向きを選択する。

## 関連ケース

- [case-02_landscape.md](case-02_landscape.md): `--landscape` オプションの詳細動作
- [case-07_trigger_md_to_pdf.md](case-07_trigger_md_to_pdf.md): デフォルト（A4 縦）との対比
