# case-08 SRT ファイルの標準形式変換

SRT 字幕ファイルを議事録作成用の標準形式に変換するケース

## 入力

| 項目 | 値 |
|-----|------|
| 起動フレーズ | "この SRT ファイルから議事録を作成して" |
| モード | 非対話 |

## 期待

- transcript-converter スキルが起動される
- ファイル拡張子から SRT 形式を判定する
- タイムスタンプと発話テキストを抽出して標準形式に変換する
- workspace/ に transcript.txt と metadata.json を出力する

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | workspace/transcript.txt と workspace/metadata.json（標準形式） |

## 分岐の根拠

SKILL.md「実行モード判定」の「ファイルパスが指定されている → 非対話」分岐。ファイル拡張子 `.srt` から SRT パーサーが選択される。

## 関連ケース

- case-02_srt_format（SRT 形式の既存ケース）
- case-07_convert_transcript（テキスト直接入力の対話フロー）
