# Case 06: ailead 形式の transcript.txt

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "このファイルから議事録を作って" |
| 入力ファイル | `transcript.txt`（ailead 形式） |
| ファイル内容例 | 下記参照 |

```
[00:00:05 - 00:00:12] 田中太郎: 本日の議題は新サービスの価格設定です。
[00:00:13 - 00:00:20] 鈴木花子: 月額プランと年額プランの2種類を検討しています。
[00:00:21 - 00:00:35] 佐藤一郎: 月額1000円、年額10000円の案を提出します。
[00:00:36 - 00:00:45] 田中太郎: 競合他社の価格帯と比較して妥当でしょうか。
[00:00:46 - 00:01:00] 鈴木花子: 競合Aは月額1200円、競合Bは月額800円です。中間価格帯として1000円は妥当だと考えます。
```

## 期待動作

1. ファイル拡張子 `.txt` のため、拡張子による形式判定では VTT/SRT に該当しない
2. 先頭行の内容が `WEBVTT` でも数字行でもないため、VTT/SRT の先頭行判定にも該当しない
3. 行パターン判定で `[HH:MM:SS - HH:MM:SS]` パターンを検出し、ailead 形式と判定する
4. `parse_ailead` 関数（または ailead パーサー相当のロジック）で処理する:
   - 正規表現 `\[(\d{2}:\d{2}:\d{2}) - (\d{2}:\d{2}:\d{2})\] (.+?): (.+)` で各行をパースする
   - 開始時刻、終了時刻、発話者名、テキストを抽出する
5. 入力が既に標準形式 `[HH:MM:SS - HH:MM:SS] 発話者名: テキスト` と一致するため、変換後の `transcript.txt` は入力とほぼ同一内容になる
6. `metadata.json` を生成する:
   - `source` フィールドに `"ailead"` を設定する
   - `participants` に田中太郎・鈴木花子・佐藤一郎を含める
   - `talkRatio` を各発話者の文字数ベースで概算する
   - `duration` を最終セグメントの endTime（60秒）- 最初のセグメントの startTime（5秒）= 55 秒として算出する
   - `system` は ailead 形式から直接判別できないため `"unknown"` を設定する
7. `workspace/transcript.txt` と `workspace/metadata.json` を出力する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| `workspace/transcript.txt` | `[00:00:05 - 00:00:12] 田中太郎: 本日の議題は新サービスの価格設定です。` 等の標準形式（入力と同一形式） |
| `workspace/metadata.json` | `source: "ailead"`, `system: "unknown"`, `duration: 55`, `participants` に田中太郎・鈴木花子・佐藤一郎を含む |
| 終了状態 | 成功（下流の minutes-composer へ引き渡し可能な状態） |

## 分岐の根拠

SKILL.md「対応入力形式」表の「ailead transcript.txt」行: パターン `[HH:MM:SS - HH:MM:SS] 名前: テキスト`、タイムスタンプ `HH:MM:SS`、自動判定 `Yes`。SKILL.md「形式自動判定の優先順」の項目3: 「行パターン（`[HH:MM:SS` → ailead 形式）」。`references/format-detection.md` のフローチャート: 拡張子不一致 → 先頭行不一致 → 行パターン判定で `[HH:MM:SS - HH:MM:SS]` を検出 → ailead 形式と判定。

## 関連ケース

- `case-01_vtt_format.md`（拡張子判定で VTT を選択するケース）
- `case-03_teams_paste.md`（行パターン判定で Teams コピペを選択するケース）
- `case-04_plain_fallback.md`（全パターン不一致でフォールバックするケース）
