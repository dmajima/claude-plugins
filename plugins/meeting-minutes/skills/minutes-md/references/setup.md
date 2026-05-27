# 環境構築

## 依存パッケージ

プラグイン共有の `references/scripts/setup/requirements.txt` を使用する。
minutes-md 固有の追加依存はない。

## venv 構築

```powershell
& chcp.com 65001 | Out-Null
[Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

pwsh -NoProfile -File "${env:CLAUDE_PLUGIN_ROOT}\references\scripts\setup\setup_venv.ps1" `
  "$SESSION_DIR\workspace"
```

`$SESSION_DIR` はセッション作業領域（`.claude/.local/work/{yyyyMMdd_nn_summary}/`）。

## venv 削除

```powershell
pwsh -NoProfile -File "${env:CLAUDE_PLUGIN_ROOT}\references\scripts\setup\teardown_venv.ps1" `
  "$SESSION_DIR\workspace"
```
