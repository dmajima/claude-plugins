# case-05 議事録のレビュー依頼

作成済みの議事録を文字起こしと突合検証するケース

## 入力

| 項目 | 値 |
|-----|------|
| 起動フレーズ | "作成した議事録をレビューして" |
| モード | 非対話 |

## 期待

- minutes-reviewer スキルが起動される
- フレッシュなサブエージェントとして独立インスタンスで実行される
- minutes.json と transcript.txt を突合検証する
- 漏れ・誤り・発言者帰属の誤りを検出する
- workspace/ に verification-log.md と review-result.json を出力する

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | workspace/verification-log.md と workspace/review-result.json |

## 分岐の根拠

SKILL.md「実行モード判定」の「workspace/ に minutes.json + transcript.txt が存在 → 非対話」分岐。フレッシュなサブエージェントとして突合検証を自動実行する。

## 関連ケース

- case-01_with_corrections（修正提案ありの検証結果）
- case-06_check_minutes（正確性チェック依頼の別フレーズ）
