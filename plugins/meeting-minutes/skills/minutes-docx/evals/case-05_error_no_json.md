# case-05 minutes.json 不在エラー

minutes.json が存在しない状態で docx 出力を依頼するエラーケース

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "議事録を Word ファイルで出力して" |
| モード | 対話 |
| 既存状態 | workspace/minutes.json が存在しない |

## 期待

- minutes-docx スキルが起動される
- workspace/minutes.json の不在を検出する
- minutes-composer の実行を提案する
- docx 生成は実行しない

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | なし（エラー検出のみ） |

## 分岐の根拠

SKILL.md「実行モード判定」の「minutes.json 不在 → 対話」分岐。入力ファイルが存在しないため、前段スキル（minutes-composer）の実行を提案して中断する。

## 関連ケース

- case-02_missing_input（同じ入力不在エラーの既存ケース）
- case-03_generate_word（正常な docx 生成フロー）
