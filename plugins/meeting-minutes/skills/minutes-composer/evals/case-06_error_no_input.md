# case-06 入力ファイル不在エラー

入力ファイルが存在しない状態で議事録作成を依頼するエラーケース

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "文字起こしから議事録を作って" |
| モード | 対話 |
| 既存状態 | workspace/transcript.txt が存在しない |

## 期待

- minutes-composer スキルが起動される
- workspace/transcript.txt の不在を検出する
- 入力ファイルのパスを再確認するようユーザーに促す
- データ取得スキル（ailead-fetcher / transcript-converter）の起動を提案する

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | なし（エラー検出のみ） |

## 分岐の根拠

SKILL.md「実行モード判定」の「入力ファイル不在 → 対話」分岐。transcript.txt が存在しないため、データ取得スキルの起動を提案して中断する。

## 関連ケース

- case-03_missing_input（同じ入力不在エラーの既存ケース）
- case-04_compose_minutes（正常な構造化フロー）
