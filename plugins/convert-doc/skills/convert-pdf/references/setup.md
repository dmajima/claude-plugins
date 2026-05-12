# convert-pdf 環境構築

## 依存パッケージ

`references/scripts/setup/requirements.txt` で管理。

| パッケージ | 用途 |
|---------|------|
| `playwright` | HTML → PDF 変換のための Chromium 制御 |
| `markdown` | `convert-html` が使用（内部呼び出しのため同梱必須） |
| `Pygments` | シンタックスハイライト（convert-html が使用） |
| `rcssmin` | CSS minify（convert-html が使用） |
| `rjsmin` | JS minify（convert-html が使用） |
| `Pillow` | 画像圧縮（convert-html が使用） |

## 構築スクリプト

セッション作業領域の workspace 配下に venv を構築する。

```bash
bash "${CLAUDE_PLUGIN_ROOT}/references/references/scripts/setup/setup_venv.sh" "$SESSION_DIR/workspace"
```

setup_venv.sh は以下を自動実行する:

1. `$WORK_DIR/.venv` に Python venv を作成
2. `$SCRIPT_DIR/requirements.txt` からパッケージをインストール
3. `playwright install chromium` で Chromium バイナリをダウンロード（初回のみ、~120MB）

## 削除スクリプト

セッション完了後は venv を削除する。

```bash
bash "${CLAUDE_PLUGIN_ROOT}/references/references/scripts/setup/teardown_venv.sh" "$SESSION_DIR/workspace"
```

## Chromium の再ダウンロードを避けたい場合

`PLAYWRIGHT_BROWSERS_PATH` 環境変数で共有キャッシュディレクトリを指定するとダウンロードが 1 回で済む。

```bash
export PLAYWRIGHT_BROWSERS_PATH="$HOME/.cache/ms-playwright"
```
