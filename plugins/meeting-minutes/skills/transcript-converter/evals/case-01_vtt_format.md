# Case 01: VTT ファイル入力

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "この VTT ファイルから議事録を作って" |
| 入力ファイル | `.vtt` 拡張子のファイル（例: `meeting_2026-05-27.vtt`） |
| ファイル内容例 | 下記参照 |

```
WEBVTT

00:00:05.000 --> 00:00:10.000
<v 田中太郎>こんにちは、本日もよろしくお願いします。</v>

00:00:10.500 --> 00:00:15.000
<v 鈴木花子>よろしくお願いいたします。</v>
```

## 期待動作

1. ファイル拡張子 `.vtt` を検出し、VTT パーサーを選択する
2. 先頭行 `WEBVTT` ヘッダの存在を確認する
3. `<v 名前>テキスト</v>` タグから発話者名とテキストを抽出する
4. `HH:MM:SS.mmm --> HH:MM:SS.mmm` からタイムスタンプを抽出する
5. 標準形式 `[HH:MM:SS - HH:MM:SS] 発話者名: テキスト` に変換する
6. `workspace/transcript.txt` と `workspace/metadata.json` を出力する
7. `metadata.json` の `source` フィールドに `"vtt"` を設定する
8. `<v>` タグの存在から `system` フィールドに `"teams"` を推定設定する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| `workspace/transcript.txt` | `[00:00:05 - 00:00:10] 田中太郎: こんにちは、本日もよろしくお願いします。` 等の標準形式 |
| `workspace/metadata.json` | `source: "vtt"`, `system: "teams"`, `participants` に田中太郎・鈴木花子を含む |
| 終了状態 | 成功（下流の minutes-composer へ引き渡し可能な状態） |

## 分岐の根拠

SKILL.md「形式自動判定の優先順」の最優先ルール: ファイル拡張子 `.vtt` → VTT パーサーを選択。`references/format-detection.md` のフローチャートで拡張子判定が最初に評価される。

## 関連ケース

- `case-02_srt_format.md`（同じ拡張子判定だが SRT 形式）
- `case-04_plain_fallback.md`（形式判定が全て不一致の場合）
