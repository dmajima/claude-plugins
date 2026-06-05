# 環境構築

## 依存パッケージ

| パッケージ | 用途 |
|-----------|------|
| `python-docx` | Word ファイル生成 |

プラグイン共有の `references/scripts/setup/requirements.txt` を使用する。

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
