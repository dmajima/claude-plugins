# Case 02: SRT ファイル入力

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "この字幕ファイルを変換して" |
| 入力ファイル | `.srt` 拡張子のファイル（例: `recording.srt`） |
| ファイル内容例 | 下記参照 |

```
1
00:00:05,000 --> 00:00:10,000
こんにちは、本日もよろしくお願いします。

2
00:00:10,500 --> 00:00:15,000
よろしくお願いいたします。
```

## 期待動作

1. ファイル拡張子 `.srt` を検出し、SRT パーサーを選択する
2. 連番 + タイムスタンプ `HH:MM:SS,mmm --> HH:MM:SS,mmm` の SRT 形式を認識する
3. 各セグメントのテキストを抽出する（SRT 形式は発話者名を含まないため `Unknown` で補填する）
4. タイムスタンプのカンマ区切り（`,`）をピリオド（`.`）に変換し、秒数に正規化する
5. 標準形式 `[HH:MM:SS - HH:MM:SS] Unknown: テキスト` に変換する
6. `workspace/transcript.txt` と `workspace/metadata.json` を出力する
7. `metadata.json` の `source` フィールドに `"srt"` を設定する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| `workspace/transcript.txt` | `[00:00:05 - 00:00:10] Unknown: こんにちは、本日もよろしくお願いします。` 等の標準形式 |
| `workspace/metadata.json` | `source: "srt"`, `system: "unknown"`, `participants` に `Unknown` を含む |
| 終了状態 | 成功 |

## 分岐の根拠

SKILL.md「形式自動判定の優先順」の最優先ルール: ファイル拡張子 `.srt` → SRT パーサーを選択。SRT 形式には発話者タグがないため、発話者名は `Unknown` で補填される。

## 関連ケース

- `case-01_vtt_format.md`（VTT 形式は発話者タグを持つ点で異なる）
- `case-05_missing_metadata.md`（発話者が `Unknown` のためメタデータ補完の確認が発生する可能性）
