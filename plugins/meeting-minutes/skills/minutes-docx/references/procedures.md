# docx 出力手順

> **環境構築**: 本手順の実行前に [`setup.md`](setup.md) で venv を構築すること。

## 前提

- `minutes-composer` が `workspace/minutes.json` を出力済みであること
- [`setup.md`](setup.md) の手順で venv が構築済みであること

## 手順

### 1. docx 生成（Start-Job ラッパー経由）

Windows + PowerShell 環境では python-docx がハングする既知事象があるため、
`run_docx_via_job.sh` 経由で起動する。

```bash
bash "$CLAUDE_PLUGIN_ROOT\references\scripts\output\run_docx_via_job.sh" \
  -PythonExe $venvPy \
  -ScriptPath "$CLAUDE_SKILL_DIR\scripts\output\generate_docx.py" \
  -InputJson "$SESSION_DIR\workspace\minutes.json" \
  -OutputDocx "$SESSION_DIR\minutes.docx" \
  -TemplatePath "$CLAUDE_SKILL_DIR\assets\template\minutes-template.docx"
```
### 3. テンプレートの再生成（必要時のみ）

テンプレートのスタイルを変更したい場合:

```bash
& $venvPy "$CLAUDE_SKILL_DIR\scripts\output\create_template.py" \
  --output "$CLAUDE_SKILL_DIR\assets\template\minutes-template.docx"
```
## トラブルシューティング

| 問題 | 対処 |
|------|------|
| `python-docx` がない | `references/scripts/setup/requirements.txt` で venv を再構築 |
| スタイルが反映されない | テンプレートの docx を再生成（`create_template.py`） |
| 日本語が文字化けする | `generate_docx.py` 先頭の `sys.stdout.reconfigure` を確認 |
| 30秒以上 stdout が 0 byte で固まる | `run_docx_via_job.sh` 経由で起動しているか確認 |
