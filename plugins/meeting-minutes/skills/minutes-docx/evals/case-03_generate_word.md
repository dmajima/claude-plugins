# case-03 議事録を Word ファイルで出力

構造化議事録データから Word ファイルを生成する基本フロー

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "議事録を Word ファイルで出力して" |
| モード | 非対話 |

## 期待

- minutes-docx スキルが起動される
- workspace/minutes.json を読み込む
- python-docx で同梱テンプレートに流し込んで docx を生成する
- セッション直下に minutes.docx を配置する
