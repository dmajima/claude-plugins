# add-design-html 環境構築

## 依存パッケージ

`references/scripts/setup/requirements.txt`（プラグイン共通）で管理。
サンプル変換で `convert.py`（convert-html）を実行するため、convert-html と同じ依存を使う。

| パッケージ | 用途 |
|---------|------|
| `markdown` | Markdown → HTML 変換（サンプル変換） |
| `Pygments` | シンタックスハイライト CSS 生成 |
| `Pillow` | 画像処理 |
| `rcssmin` / `rjsmin` | CSS / JS のミニファイ |
| `requests` | mermaid.ink アクセス（サンプルに mermaid を含む場合） |

検証スクリプト（`validate_css.py` / `validate_html.py`）自体は標準ライブラリのみで動作する。

## 構築スクリプト

セッション作業領域の workspace 配下に venv を構築する。

```bash
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/setup_venv.sh" -WorkDir "$SESSION_DIR/workspace"
```

## 削除スクリプト

```bash
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/teardown_venv.sh" -WorkDir "$SESSION_DIR/workspace"
```
