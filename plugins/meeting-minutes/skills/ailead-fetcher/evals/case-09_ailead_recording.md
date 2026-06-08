# case-09 ailead の録画データ取得

ailead の録画・文字起こしの取得を依頼するケース

## 入力

| 項目 | 値 |
|-----|------|
| 起動フレーズ | "ailead の録画と文字起こしを取得して" |
| モード | 対話 |

## 期待

- ailead-fetcher スキルが起動される
- 共有 URL が未指定のため、ユーザーに ailead 共有リンクの入力を求める
- URL 取得後に GraphQL API でデータを取得する

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | ユーザーが URL を提供した後、workspace/ に transcript.txt, metadata.json, summary.md, response.json を出力 |

## 分岐の根拠

SKILL.md「実行モード判定」の「URL なし or 不正形式 → 対話」分岐。起動フレーズに URL が含まれないため対話モードに遷移する。

## 関連ケース

- case-07_no_url_interactive（同じ URL 未指定の対話フロー）
- case-08_fetch_share_link（URL 指定ありの非対話フロー）
