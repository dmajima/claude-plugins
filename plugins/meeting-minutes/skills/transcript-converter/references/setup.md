# 環境構築

## 依存パッケージ

プラグイン共有の `references/scripts/setup/requirements.txt` を使用する。
transcript-converter 固有の追加依存はない。

## venv 構築

```bash
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/setup_venv.sh" \
  "$SESSION_DIR/workspace"
```
`$SESSION_DIR` はセッション作業領域（`.claude/.local/work/{yyyyMMdd_nn_summary}/`）。

## venv 削除

```bash
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/teardown_venv.sh" \
  "$SESSION_DIR/workspace"
```
