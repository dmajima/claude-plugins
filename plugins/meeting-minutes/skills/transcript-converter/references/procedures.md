# 変換手順

## 前提

- [`setup.md`](setup.md) の手順で venv が構築済みであること
- 入力ファイルがセッション作業領域の `inputs/` に配置されていること

## 手順

### 1. 入力の配置

ユーザーが直接テキストを貼り付けた場合:
- セッション作業領域の `inputs/transcript_raw.txt` に保存する

ファイルパスが指定された場合:
- そのパスをそのまま入力として使用する

### 2. Python スクリプトで変換

```bash
"$SESSION_DIR/workspace/.venv/Scripts/python" \
  "$CLAUDE_SKILL_DIR/scripts/convert/convert_transcript.py" \
  --input "$SESSION_DIR/inputs/transcript_raw.txt" \
  --output "$SESSION_DIR/workspace" \
  --title "会議タイトル"
```
### 3. 出力確認

以下が生成される:

| ファイル | 配置先 | 内容 |
|---------|-------|------|
| `transcript.txt` | `workspace/` | 標準形式の文字起こし |
| `metadata.json` | `workspace/` | 会議メタデータ |

### 4. メタデータの補完

Python スクリプトで自動推定できないフィールドがある場合、
Claude が `AskUserQuestion` でユーザーに確認する:

- 会議タイトル（ファイル名から推定できない場合）
- 会議日時（タイムスタンプがない場合）
- 参加者の所属（発話者名のみ判明している場合）

### 5. 下流スキルへの引き渡し

変換完了後、`minutes-composer` に引き渡す。
`workspace/transcript.txt` と `workspace/metadata.json` が connector:ailead と同一形式であるため、
`minutes-composer` はデータソースを意識せずに処理できる。
