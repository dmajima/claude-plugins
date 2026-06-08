# スクリプト OK/NG 例と移行ガイド

ルール本体は `../policies/scripts-policy.md` を参照。本ファイルは具体的な OK/NG 例と既存スキルの移行手順を収録する。

## 4. OK / NG 例

### 4.1 NG 例（インライン記載してはならない）

以下は `references/automated-checks.md` に直接インライン Python を書いた違反例。

```python
import yaml, json

with open(skill_md, 'r', encoding='utf-8') as f:
    content = f.read()
parts = content.split('---', 2)
yaml.safe_load(parts[1])
```

理由: 12 行を超え、制御構造・例外処理を含み、再利用が見込まれる。

### 4.2 OK 例（呼び出し方の提示）

`references/scripts/checks/run_checks.py` に実行ロジックを切り出し、md には呼び出し方のみを記載する:

```bash
"" "${CLAUDE_SKILL_DIR}/references/scripts/checks/run_checks.py" 
  --target "${TARGET_DIR}" --output "${OUT_JSON}"
```

理由: 実行ロジックは `references/scripts/checks/run_checks.py` に切り出され、md には呼び出し方のみが残る。

### 4.3 OK 例（単発コマンド）

```bash
mkdir -p .claude/.local/work/20260501_01_foo/{inputs,workspace}
```

理由: 1 行・1 責務・制御構造なし。

### 4.4 NG 例（venv 構築をインラインで書く）

以下の書き方は禁止（venv ライフサイクルはプラグイン直下スクリプトに統一）:

```bash
python -m venv "$WORKSPACE/.venv"
"$WORKSPACE/.venv/Scripts/pip" install --quiet -r requirements.txt
```

理由: venv ライフサイクルはプラグイン直下に事前ビルドされたスクリプトを呼ぶ運用に統一する。

### 4.5 OK 例（venv 構築の呼び出し）

```bash
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/setup_venv.sh" \
  -WorkDir "$SessionDir/workspace" \
  -RequirementsPath "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/requirements.txt"
```

## 8. 移行ガイド（既存スキル向け）

既存スキルが本ポリシーに違反している場合の移行手順:

1. **インラインスクリプトの切り出し**
   - 該当コードブロックを `references/scripts/{業務}/{name}.py` または `.sh` に切り出す
   - md は呼び出し例（5 行以下）に置換する

2. **トップレベル `scripts/` から `references/scripts/` への移動**
   - `plugins/{name}/scripts/...` を `plugins/{name}/references/scripts/...` へ移動
   - `plugins/{name}/skills/{skill}/scripts/...` を `plugins/{name}/skills/{skill}/references/scripts/...` へ移動

3. **venv スクリプトのプラグイン直下昇格**
   - スキル配下の `references/scripts/setup/setup_venv.sh` 等を削除
   - プラグイン直下 `references/scripts/setup/` に統合（既存があれば再利用）
   - `requirements.txt` をプラグイン直下に統合し、全スキルの依存をマージ

4. **スキル側 references の更新**
   - 「環境構築」節を「プラグイン直下スクリプトの呼び出し」に書き換え
   - スキル独自の Python バージョン要件等は `setup_venv.sh` の `-MinPythonVersion` パラメータで渡す