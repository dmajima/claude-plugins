# convert-html 環境構築手順

## 依存パッケージ

`scripts/setup/requirements.txt` で一元管理。パッケージ追加・変更はこのファイルを編集する。

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
| `scripts/setup/setup_venv.sh` | venv 作成 + パッケージインストール | `<WORK_DIR>` |
| `scripts/setup/teardown_venv.sh` | venv 削除 | `<WORK_DIR>` |
| `scripts/convert/convert.py` | MD → HTML 変換 | `procedures.md` 参照 |
| `scripts/setup/requirements.txt` | 依存パッケージ定義 | — |

## ステップ

### 1. ワークディレクトリ作成

```bash
SESSION_DIR=".claude/.local/work/yyyyMMdd_nn_convert_html"
mkdir -p "$SESSION_DIR/inputs"
mkdir -p "$SESSION_DIR/workspace"
```

- 最終成果物（HTML）は `$SESSION_DIR` 直下に出力する
- 中間生成物・venv は `$SESSION_DIR/workspace/` 配下に置く
- ユーザー提供の入力Markdownを `$SESSION_DIR/inputs/` に置いてもよい（読み取り専用）

### 2. venv 構築

venv は `workspace/` 配下に作成する（`workspace/.venv/`）。
スキル自身のスクリプトは `${CLAUDE_SKILL_DIR}` 経由で参照する（インストール形態に依存しないポータブルパス記法）。

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/setup/setup_venv.sh" "$SESSION_DIR/workspace"
```

### 3. venv 削除（スキル完了後）

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/setup/teardown_venv.sh" "$SESSION_DIR/workspace"
```
