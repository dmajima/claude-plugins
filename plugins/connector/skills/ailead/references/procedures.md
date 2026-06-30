# 実行手順

> **環境構築**: 本手順の実行前に [`setup.md`](setup.md) で venv を構築すること。

## 1. 共有 URL から share key を抽出

URL パターン: `https://dashboard.ailead.app/share/<share-key>`

```python
import re
url = "https://dashboard.ailead.app/share/GCsCUNU4G4s1UxUxloJ0CQbapqQ5hGrai_aAlEP2VXA"
key = re.search(r'/share/([^/?#]+)', url).group(1)
```

## 2. Python スクリプトによるデータ取得（推奨）

```bash
"$SESSION_DIR/workspace/.venv/Scripts/python" \
  "${CLAUDE_SKILL_DIR}/scripts/fetch/fetch_share.py" \
  --url "https://dashboard.ailead.app/share/<key>" \
  --output "$SESSION_DIR/workspace"
```

スクリプトは以下を自動実行する:
1. share key の抽出
2. HTML ページ取得 → `buildId` 抽出
3. 事前解析済み `operationHash` で GraphQL API 呼び出し
4. 失敗時は JS チャンクから `operationHash` を再抽出してリトライ
5. レスポンスをパースし、4ファイルを出力

## 3. 出力ファイル

| ファイル | 配置先 | 内容 |
|---------|-------|------|
| `response.json` | `workspace/` | GraphQL レスポンス全文 |
| `transcript.txt` | `workspace/` | 文字起こし全文（`[HH:MM:SS - HH:MM:SS] 発話者: テキスト` 形式） |
| `summary.md` | `workspace/` | AI会議要約（Markdown形式: 概要・キーワード・トピック別） |
| `metadata.json` | `workspace/` | 会議メタデータ（JSON形式） |

### metadata.json の構造

```json
{
  "title": "会議タイトル",
  "startDatetime": "2026-06-01T10:00:00Z",
  "duration": 3600,
  "system": "TEAMS",
  "source": "ailead",
  "expirationDatetime": "2026-07-01T10:00:00Z",
  "hostUser": "山田 太郎",
  "hlsUrl": "https://dashboard.ailead.app/api/v1/share/media.m3u8?key=...",
  "participants": [
    {"name": "山田 太郎", "talkRatio": 0.45, "isHost": true},
    {"name": "佐藤 花子", "talkRatio": 0.35, "isHost": false}
  ],
  "transcriptCount": 120,
  "topicCount": 5
}
```

## 4. タイムスタンプの算出

`transcripts` の `startTime` / `endTime` は正規化値（0.0〜1.0）。
実際の秒数は `duration`（秒数）を乗算して算出する。

```python
actual_seconds = transcript["startTime"] * duration_seconds
```

秒 → `HH:MM:SS` 変換:
```python
def format_time(seconds):
    h, rem = divmod(int(seconds), 3600)
    m, s = divmod(rem, 60)
    return f"{h:02d}:{m:02d}:{s:02d}"
```

## 5. エラーハンドリング

| エラー | 原因 | 対処 |
|-------|------|------|
| `CLIENT_CODE_OUT_OF_DATE` | operationHash が古い | スクリプトが JS チャンクから自動再抽出 |
| `PERSISTED_QUERY_NOT_FOUND` | ハッシュ形式の不一致 | スクリプトが JS チャンクからフォールバック |
| HTTP 404 on HTML | 共有リンクの期限切れ | `expirationDatetime` を確認し報告 |
| 空の `transcripts` | 文字起こし未完了 | `callTasks` の `TRANSCRIPT` ステータスを確認 |
| パスワード要求 | パスワード保護リンク | 「パスワード保護リンクは非対応」と報告 |
| `callSummary` が null | AI要約が未生成 | 正常系として処理続行。要約なしで報告 |

## 6. HLS 動画のダウンロード（参考情報・手動操作）

ffmpeg がインストール済みの場合、HLS URL からダウンロード可能。本スキルの責務外。

```bash
ffmpeg -i "https://dashboard.ailead.app/api/v1/share/media.m3u8?key=$shareKey" -c copy output.mp4
```
