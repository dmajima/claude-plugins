# convert-pptx 環境構築

## 依存パッケージ

`scripts/setup/requirements.txt` で管理。

| パッケージ | 用途 |
|---------|------|
| `python-pptx` | PPTX ファイルの生成 |
| `Pillow` | 画像の読み込み・サイズ取得 |
| `requests` | mermaid.ink API から PNG 取得 |
| `Pygments` | コードブロックのシンタックスハイライト（トークン→色） |

## 構築スクリプト

セッション作業領域の workspace 配下に venv を構築する。

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/setup/setup_venv.sh" "$SESSION_DIR/workspace"
```

## 削除スクリプト

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/setup/teardown_venv.sh" "$SESSION_DIR/workspace"
```
