# case-09 資料を PDF で出力

ユーザーが作成した資料を PDF で出力するよう依頼した場合のトリガー。

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "この資料を PDF で出力して" |
| モード | 対話 |

## 期待動作

- convert-pdf スキルが起動する
- 入力ファイルのパスを確認する
- A4 縦・全周 20mm マージン・背景色印刷ありのデフォルト設定で PDF を生成する
- Playwright Chromium で HTML を PDF にレンダリングする

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | A4 縦・全周 20mm マージン・背景色印刷ありの PDF ファイル |

## 分岐の根拠

SKILL.md の実行モード判定表で自然言語依頼による対話モードに該当。description の「資料を PDF で出力」パターンに合致し、スキルトリガーとして認識される。

## 関連ケース

- [case-07_trigger_md_to_pdf.md](case-07_trigger_md_to_pdf.md): 基本的な変換トリガー
- [case-02_landscape.md](case-02_landscape.md): landscape オプション指定時の対比
