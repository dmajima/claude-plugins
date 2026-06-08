# case-04 文字起こしから議事録を作成

文字起こしデータが取得済みの状態で議事録の構成を依頼するケース

## 入力

| 項目 | 値 |
|-----|------|
| 起動フレーズ | "取得した文字起こしから議事録を構成して" |
| モード | 非対話 |

## 期待

- minutes-composer スキルが起動される
- workspace/ の transcript.txt と metadata.json を読み込む
- 議題・議論内容・決定事項・アクションアイテムを構造化する
- workspace/minutes.json をスキーマ準拠の JSON として出力する

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | workspace/minutes.json（スキーマ準拠の構造化議事録データ） |

## 分岐の根拠

SKILL.md「実行モード判定」の「workspace/ に transcript.txt + metadata.json が存在 → 非対話」分岐。入力データの種別判定後、構造化処理を自動実行する。

## 関連ケース

- case-01_ailead_flow（ailead フローでの構造化）
- case-02_generic_flow（汎用フローでの構造化）
