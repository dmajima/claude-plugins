# convert-html 環境構築手順

## 依存パッケージ

`references/scripts/setup/requirements.txt` で一元管理。パッケージ追加・変更はこのファイルを編集する。

| パッケージ | 用途 |
|---|---|
| `markdown` | Markdown → HTML 変換 |
| `Pygments` | コードブロックのシンタックスハイライト |
| `rcssmin` | CSS minify（埋め込み前の圧縮） |
| `rjsmin` | JS minify（埋め込み前の圧縮） |
| `Pillow` | 200KB超過画像の圧縮処理 |

## スクリプト一覧

| スクリプト | 用途 | 引数 |
|---|---|---|
| `references/scripts/setup/setup_venv.sh` | venv 作成 + パッケージインストール | `-WorkDir <WORK_DIR>` |
| `references/scripts/setup/teardown_venv.sh` | venv 削除 | `-WorkDir <WORK_DIR>` |
| `references/scripts/convert-html/convert.py` | MD → HTML 変換 | `procedures.md` 参照 |
| `references/scripts/setup/requirements.txt` | 依存パッケージ定義 | — |

## ステップ

### 1. ワークディレクトリ作成

```bash
New-Item -ItemType Directory -Force -Path "$SessionDir/inputs" | Out-Null
New-Item -ItemType Directory -Force -Path "$SessionDir/workspace" | Out-Null
```

<details><summary>PowerShell フォールバック</summary>

```powershell
$SessionDir = ".claude/.local/work/yyyyMMdd_nn_convert_html"
New-Item -ItemType Directory -Force -Path "$SessionDir/inputs" | Out-Null
New-Item -ItemType Directory -Force -Path "$SessionDir/workspace" | Out-Null
```

</details>

- 最終成果物（HTML）は `$SessionDir` 直下に出力する
- 中間生成物・venv は `$SessionDir/workspace/` 配下に置く
- ユーザー提供の入力Markdownを `$SessionDir/inputs/` に置いてもよい（読み取り専用）

### 2. venv 構築

venv は `workspace/` 配下に作成する（`workspace/.venv/`）。
スキル自身のスクリプトは `$env:CLAUDE_SKILL_DIR` 経由で参照する（インストール形態に依存しないポータブルパス記法）。

```bash
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/setup_venv.sh" -WorkDir "$SessionDir/workspace"
```

<details><summary>PowerShell フォールバック</summary>

```powershell
pwsh -NoProfile -File "$env:CLAUDE_PLUGIN_ROOT/references/scripts/setup/setup_venv.ps1" -WorkDir "$SessionDir/workspace"
```

</details>

### 3. venv 削除（スキル完了後）

```bash
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/teardown_venv.sh" -WorkDir "$SessionDir/workspace"
```

<details><summary>PowerShell フォールバック</summary>

```powershell
pwsh -NoProfile -File "$env:CLAUDE_PLUGIN_ROOT/references/scripts/setup/teardown_venv.ps1" -WorkDir "$SessionDir/workspace"
```

</details>
