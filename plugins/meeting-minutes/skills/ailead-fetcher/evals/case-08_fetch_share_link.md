# case-08 ailead 共有リンクからデータ取得

ailead の共有リンク URL を指定してデータを取得する基本フロー

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "この ailead の共有リンクから議事録を作成して https://dashboard.ailead.app/share/abc123" |
| モード | 非対話 |

## 期待

- ailead-fetcher スキルが起動される
- 共有 URL から share key を抽出する
- GraphQL API 経由で文字起こし・会議要約・参加者情報を取得する
- workspace/ に transcript.txt, metadata.json, summary.md, response.json を出力する
