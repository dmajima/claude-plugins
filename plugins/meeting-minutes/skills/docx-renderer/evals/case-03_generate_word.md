# case-03 議事録を Word ファイルで出力

構造化議事録データから Word ファイルを生成する基本フロー

## 入力

| 項目 | 値 |
|-----|------|
| 起動フレーズ | "議事録を Word ファイルで出力して" |
| モード | 非対話 |

## 期待

- docx-renderer スキルが起動される
- workspace/minutes.json を読み込む
- python-docx で同梱テンプレートに流し込んで docx を生成する
- セッション直下に minutes.docx を配置する

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | セッション直下の minutes.docx（テンプレートベースの Word ファイル） |

## 分岐の根拠

SKILL.md「実行モード判定」の「workspace/minutes.json が存在 → 非対話」分岐。正常な入力から docx 生成の標準パスを実行する。

## 関連ケース

- case-01_normal（同じ正常変換フロー）
- case-04_docx_output（docx 変換依頼の別フレーズ）
