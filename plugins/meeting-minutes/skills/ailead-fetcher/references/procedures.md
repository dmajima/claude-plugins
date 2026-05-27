# 実行手順

> **環境構築**: 本手順の実行前に [`setup.md`](setup.md) で venv を構築すること。

## 1. 共有 URL から share key を抽出

URL パターン: `https://dashboard.ailead.app/share/<share-key>`

```python
import re
url = "https://dashboard.ailead.app/share/GCsCUNU4G4s1UxUxloJ0CQbapqQ5hGrai_aAlEP2VXA"
key = re.search(r'/share/([^/?#]+)', url).group(1)
```

## 2. HTML から buildId を取得

```powershell
$resp = Invoke-WebRequest -Uri "https://dashboard.ailead.app/share/$key" -UseBasicParsing
$buildId = [regex]::Match($resp.Content, '"buildId":"([^"]+)"').Groups[1].Value
```

buildId は Next.js のデプロイごとに変わるため、毎回 HTML から動的に取得する。

## 3. JS チャンクから operationHash を取得（必要時のみ）

通常は `api-spec.md` セクション 7 に記載の既知ハッシュを使用する。
取得失敗（`CLIENT_CODE_OUT_OF_DATE` エラー）時のみ以下で再抽出する。

```powershell
# HTML から share ページの JS チャンク URL を抽出
$jsUrl = [regex]::Match($resp.Content, '/_next/static/chunks/pages/share/%5Bkey%5D-[^"]+\.js').Value
$jsResp = Invoke-WebRequest -Uri "https://dashboard.ailead.app$jsUrl" -UseBasicParsing
$hash = [regex]::Match($jsResp.Content, 'externalShare/dataflow/query.*?hash:"([0-9a-f]{64})"').Groups[1].Value
```

## 4. GraphQL API を呼び出す

### 4.1 Python スクリプト経由（推奨）

```powershell
& chcp.com 65001 | Out-Null
[Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$venvPy = "$SESSION_DIR\workspace\.venv\Scripts\python.exe"
& $venvPy "${env:CLAUDE_SKILL_DIR}\scripts\fetch\fetch_share.py" `
  --url "https://dashboard.ailead.app/share/<key>" `
  --output "$SESSION_DIR\workspace"
```

スクリプトは以下を自動実行する:
- share key の抽出
- buildId の取得
- operationHash の解決（既知ハッシュ → 失敗時に JS チャンクから再抽出）
- GraphQL クエリ実行
- 結果の JSON 保存 + 文字起こしテキスト出力

### 4.2 PowerShell 直接実行

```powershell
$body = @{
    operationName = 'externalShare'
    variables = @{ key = $shareKey }
    extensions = @{
        operationHash = $hash
        buildId = $buildId
    }
} | ConvertTo-Json -Depth 5

$jsonBody = [System.Text.Encoding]::UTF8.GetBytes($body)
$resp = Invoke-WebRequest -Uri 'https://dashboard.ailead.app/api/v2/graphql' `
    -Method Post -Body $jsonBody `
    -ContentType 'application/json; charset=utf-8' -UseBasicParsing
```

## 5. レスポンスの処理

### 5.1 成果物の配置

| ファイル | 配置先 | 内容 |
|---------|-------|------|
| `response.json` | `workspace/` | GraphQL レスポンス全文 |
| `transcript.txt` | `workspace/` | 文字起こし全文（発話者・タイムスタンプ付き） |
| `summary.md` | `workspace/` | AI 会議要約（Markdown 形式） |
| `metadata.json` | `workspace/` | 会議メタデータ（タイトル・参加者・HLS URL 等） |

### 5.2 タイムスタンプの算出

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

## 6. HLS 動画のダウンロード（オプション）

ffmpeg がインストール済みの場合、HLS URL からダウンロード可能。

```powershell
# MP4 (映像+音声)
ffmpeg -i "https://dashboard.ailead.app/api/v1/share/media.m3u8?key=$shareKey" -c copy output.mp4

# 音声のみ
ffmpeg -i "https://dashboard.ailead.app/api/v1/share/media.m3u8?key=$shareKey" -vn -acodec copy output.aac
```

## 7. エラーハンドリング

| エラー | 原因 | 対処 |
|-------|------|------|
| `CLIENT_CODE_OUT_OF_DATE` | operationHash が古い | 手順 3 で JS チャンクから再抽出 |
| `PERSISTED_QUERY_NOT_FOUND` | ハッシュ形式の不一致 | `extensions.operationHash` 形式であることを確認 |
| HTTP 404 on HTML | 共有リンクの期限切れ | `expirationDatetime` を確認 |
| 空の `transcripts` | 文字起こし未完了 | `callTasks` の `TRANSCRIPT` ステータスを確認 |
| パスワード要求 | パスワード保護リンク | ユーザーにパスワードを確認（未実装） |
