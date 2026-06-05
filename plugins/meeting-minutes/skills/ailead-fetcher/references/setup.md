# 環境構築

## 依存パッケージ

| パッケージ | 用途 |
|-----------|------|
| `requests` | HTTP リクエスト |

## venv 構築

```bash
& chcp.com 65001 | Out-Null
[Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

bash "$CLAUDE_PLUGIN_ROOT\references\scripts\setup\setup_venv.sh" \
  "$SESSION_DIR\workspace"
```
`$SESSION_DIR` はセッション作業領域（`.claude/.local/work/{yyyyMMdd_nn_summary}/`）。

## venv 削除

```bash
bash "$CLAUDE_PLUGIN_ROOT\references\scripts\setup\teardown_venv.sh" \
  "$SESSION_DIR\workspace"
```
## 外部ツール（オプション）

| ツール | 用途 | 必須 |
|-------|------|------|
| `ffmpeg` | HLS 動画のダウンロード・変換 | いいえ |
