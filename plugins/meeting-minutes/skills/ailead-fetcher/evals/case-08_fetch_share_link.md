# case-08 ailead 共有リンクからデータ取得

ailead の共有リンク URL を指定してデータを取得する基本フロー

## 入力

| 項目 | 値 |
|-----|------|
| 起動フレーズ | "この ailead の共有リンクから議事録を作成して https://dashboard.ailead.app/share/abc123" |
| モード | 非対話 |

## 期待

- ailead-fetcher スキルが起動される
- 共有 URL から share key を抽出する
- GraphQL API 経由で文字起こし・会議要約・参加者情報を取得する
- workspace/ に transcript.txt, metadata.json, summary.md, response.json を出力する

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | workspace/ に transcript.txt, metadata.json, summary.md, response.json の4ファイルを出力 |

## 分岐の根拠

SKILL.md「実行フロー」の正常パス。共有 URL が引数で指定されているため非対話モードで自動実行される。

## 関連ケース

- case-01_success（同じ正常取得フローの詳細版）
- case-09_ailead_recording（URL 未指定で対話モードになるケース）
