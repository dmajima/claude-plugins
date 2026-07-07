# add-design-pptx 環境構築

## 依存パッケージ

`references/scripts/setup/requirements.txt`（プラグイン共通）で管理。
サンプル変換で `convert_pptx.py` を実行するため、convert-pptx と同じ依存を使う。

| パッケージ | 用途 |
|---------|------|
| `python-pptx` | サンプル変換での PPTX 生成・テーマ検証（load_theme の import） |
| `Pillow` | 画像の読み込み・サイズ取得 |
| `requests` | mermaid.ink API から PNG 取得 |
| `Pygments` | コードブロックのシンタックスハイライト |

## 構築スクリプト

セッション作業領域の workspace 配下に venv を構築する。

```bash
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/setup_venv.sh" -WorkDir "$SESSION_DIR/workspace"
```

## 削除スクリプト

```bash
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/teardown_venv.sh" -WorkDir "$SESSION_DIR/workspace"
```
