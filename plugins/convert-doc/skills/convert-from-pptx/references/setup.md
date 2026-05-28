# convert-from-pptx 環境構築

## 依存パッケージ

`references/scripts/setup/requirements.txt` で管理。

| パッケージ | 用途 |
|---------|------|
| `python-pptx` | PPTX ファイルのパース・要素抽出 |
| `lxml` | SmartArt の `diagramData` XML を解析（XXE 対策として `XMLParser(resolve_entities=False, no_network=True, load_dtd=False, huge_tree=False)` を使用） |

## 構築スクリプト

セッション作業領域の workspace 配下に venv を構築する。

```bash
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/setup_venv.sh" \
  -WorkDir "$SESSION_DIR/workspace" \
  -RequirementsPath "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/requirements.txt"
```

<details><summary>PowerShell フォールバック</summary>

```powershell
pwsh -NoProfile -File "${env:CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.ps1" `
  -WorkDir "$SESSION_DIR/workspace" `
  -RequirementsPath "${env:CLAUDE_PLUGIN_ROOT}/references/scripts/setup/requirements.txt"
```

</details>

## 削除スクリプト

```bash
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/teardown_venv.sh" \
  -WorkDir "$SESSION_DIR/workspace"
```

<details><summary>PowerShell フォールバック</summary>

```powershell
pwsh -NoProfile -File "${env:CLAUDE_PLUGIN_ROOT}/references/scripts/setup/teardown_venv.ps1" `
  -WorkDir "$SESSION_DIR/workspace"
```

</details>

## オフライン要件

本スキルは外部 API へのアクセスを行わない。インターネット接続がない環境でも変換可能。
