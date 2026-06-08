# case-10 不正 URL エラー

ailead 共有リンクとして不正な URL が提示されたエラーケース

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "この ailead リンクから議事録を作成して https://invalid-url" |
| モード | 対話 |

## 期待

- ailead-fetcher スキルが起動される
- URL が `dashboard.ailead.app/share/` 形式に一致しないことを検出する
- URL 不正のエラーメッセージをユーザーに提示する
- 正しい ailead 共有リンクの形式を案内する

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | なし（エラー検出のみ） |

## 分岐の根拠

SKILL.md「実行モード判定」の「URL なし or 不正形式 → 対話」分岐。提示された URL が ailead の共有リンク形式に一致しないため、ユーザーに正しい形式を案内する。

## 関連ケース

- case-07_no_url_interactive（URL 未指定で対話モードに遷移するケース）
- case-03_expired_link（有効期限切れの URL エラー）
