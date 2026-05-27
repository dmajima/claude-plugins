# docx 出力手順

## 前提

- `minutes-composer` が `minutes.json` を出力済みであること
- プラグイン共有の `references/scripts/setup/requirements.txt` で venv が構築済みであること

## 手順

### 1. venv 構築（未構築の場合）

```powershell
& chcp.com 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

pwsh -NoProfile -File "${env:CLAUDE_PLUGIN_ROOT}\references\scripts\setup\setup_venv.ps1" `
  "$SESSION_DIR\workspace"
```

### 2. docx 生成

```powershell
$venvPy = "$SESSION_DIR\workspace\.venv\Scripts\python.exe"
& $venvPy "${env:CLAUDE_SKILL_DIR}\scripts\output\generate_docx.py" `
  --input "$SESSION_DIR\minutes.json" `
  --template "${env:CLAUDE_SKILL_DIR}\assets\template\minutes-template.docx" `
  --output "$SESSION_DIR\minutes.docx"
```

### 3. テンプレートの再生成（必要時のみ）

テンプレートのスタイルを変更したい場合:

```powershell
& $venvPy "${env:CLAUDE_SKILL_DIR}\scripts\output\create_template.py" `
  --output "${env:CLAUDE_SKILL_DIR}\assets\template\minutes-template.docx"
```

## トラブルシューティング

| 問題 | 対処 |
|------|------|
| `python-docx` がない | `references/scripts/setup/requirements.txt` で venv を再構築 |
| スタイルが反映されない | テンプレートの docx を再生成（`create_template.py`） |
| 日本語が文字化けする | `generate_docx.py` 先頭の `sys.stdout.reconfigure` を確認 |
