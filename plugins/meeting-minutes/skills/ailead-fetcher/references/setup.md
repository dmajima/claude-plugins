# 環境構築

## 依存パッケージ

| パッケージ | 用途 |
|-----------|------|
| `requests` | HTTP リクエスト |

## venv 構築

```powershell
& chcp.com 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

pwsh -NoProfile -File "${env:CLAUDE_SKILL_DIR}\scripts\setup\setup_venv.ps1" `
  "$SESSION_DIR\workspace"
```

`$SESSION_DIR` はセッション作業領域（`.claude/.local/work/{yyyyMMdd_nn_summary}/`）。

## venv 削除

```powershell
pwsh -NoProfile -File "${env:CLAUDE_SKILL_DIR}\scripts\setup\teardown_venv.ps1" `
  "$SESSION_DIR\workspace"
```

## 外部ツール（オプション）

| ツール | 用途 | 必須 |
|-------|------|------|
| `ffmpeg` | HLS 動画のダウンロード・変換 | いいえ |
