# case-05 議事録のレビュー依頼

作成済みの議事録を文字起こしと突合検証するケース

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "作成した議事録をレビューして" |
| モード | 非対話 |

## 期待

- minutes-reviewer スキルが起動される
- フレッシュなサブエージェントとして独立インスタンスで実行される
- minutes.json と transcript.txt を突合検証する
- 漏れ・誤り・発言者帰属の誤りを検出する
- workspace/ に verification-log.md と review-result.json を出力する
