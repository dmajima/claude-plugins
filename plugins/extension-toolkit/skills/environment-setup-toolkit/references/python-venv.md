# Python venv 仕様

Python 仮想環境（venv）の詳細仕様と互換性ガイド。

## 1. venv の配置

| 配置先 | パス |
|-------|-----|
| セッション作業領域内 | `.claude/.local/work/{yyyyMMdd_nn_summary}/workspace/.venv` |
| プラグインのデータ領域内（永続必要時のみ） | `${CLAUDE_PLUGIN_DATA}/.venv`（推奨度低） |

通常は **セッション作業領域内** を採用。タスク完了後に teardown で削除する。

## 2. クロスプラットフォーム互換

| OS | venv のバイナリ配置 |
|---|------------------|
| Windows | `<.venv>/Scripts/python.exe` `<.venv>/Scripts/pip.exe` |
| Unix / macOS | `<.venv>/bin/python` `<.venv>/bin/pip` |

スクリプトでは両方を試行する:

```bash
if [ -f "${VENV_DIR}/Scripts/python" ] || [ -f "${VENV_DIR}/Scripts/python.exe" ]; then
  PYTHON="${VENV_DIR}/Scripts/python"
else
  PYTHON="${VENV_DIR}/bin/python"
fi
```

## 3. 利用するパッケージ

| パッケージ | 用途 |
|----------|------|
| `pip` | パッケージ管理（最新版に upgrade 推奨） |
| `setuptools` | 古い setup.py ベースのインストールに必要 |
| `wheel` | バイナリパッケージのビルド・インストール |

base venv にこれらが含まれる。最新化推奨:

```bash
"${PYTHON}" -m pip install --upgrade pip setuptools wheel
```

## 4. requirements.txt の書き方

### 4.1 推奨形式

```text
# コメント可
package_name==1.2.3        # 厳密一致（再現性最優先）
another_pkg>=2.0,<3.0       # 範囲指定
optional_pkg                # バージョン指定なし（最新）
```

### 4.2 推奨パターン

| 用途 | 推奨形式 |
|-----|---------|
| 再現性最優先 | 厳密一致（`==1.2.3`） |
| 互換範囲を許容 | `>=1.0,<2.0` |
| 最新を許容 | バージョン指定なし |

### 4.3 依存パッケージはプラグイン直下に統合（ADR-024）

各スキルの依存もすべて **プラグイン直下** の `references/scripts/setup/requirements.txt` に統合する。スキルごとの個別 `requirements.txt` は禁止:

```
plugins/{plugin-name}/
└── references/
    └── scripts/
        └── setup/
            └── requirements.txt    # 全スキルの依存をマージ
```

## 5. venv の独立性

| 観点 | 内容 |
|-----|------|
| システム Python | venv は base Python から独立してパッケージを管理 |
| 別 venv との独立 | 別タスクの venv に影響しない |
| シェル環境変数 | venv をアクティベートしないとシステム pip が動く |

明示的な venv 内 pip 利用:

```bash
"${VENV_DIR}/Scripts/python" -m pip install <pkg>   # アクティベート不要
```

## 6. アクティベート vs 直接実行

| 方法 | 推奨度 |
|-----|-------|
| `source <.venv>/bin/activate` | スクリプト内では非推奨（環境変数が残る） |
| 直接 `<.venv>/bin/python` を呼ぶ | **推奨**（明示的・副作用なし） |

スクリプトでは **直接実行** を採用する。

## 7. teardown の安全性

`teardown_venv.sh` の安全装置は 3 段構成。詳細は実装（プラグイン直下 `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/teardown_venv.sh`）を参照。要点のみ記載:

| 段 | 内容 |
|---|------|
| 1 | パスを `realpath -m`（fallback: `readlink -f`）で正規化し、シンボリックリンク迂回を防ぐ |
| 2 | 正規化後パスが `.claude/.local/` を含むか `case` 文で確認。含まなければ拒否 |
| 3 | 既知のシステムパス（`/`、`/root`、`/home`、`/etc`、`/usr`、`/var`、`/bin`、`/sbin`、`/opt`、`/Users`、Windows ドライブルート）に該当する場合は二重チェックで拒否 |

範囲外の `.venv` の誤削除を防ぐと同時に、シンボリックリンク経由の迂回攻撃にも対応する。

## 8. キャッシュとパフォーマンス

| 戦略 | 効果 |
|-----|------|
| pip キャッシュ利用 | 再インストール時の高速化（`pip install` のデフォルト） |
| venv 再利用 | 既存 venv があれば作成スキップ |
| 依存パッケージのバージョン固定 | キャッシュヒット率向上 |

## 9. グローバルルールとの関係

プラグイン内 SSOT として、venv は **必ずセッション作業領域 `.claude/.local/work/{...}/workspace/.venv`** に作成、タスク完了で削除する。グローバルルール（`~/.claude/rules/tools/python-venv.md`）は **存在すれば追加情報** として参照可能（ADR-022、不在時は本ルールのみで動作）:

- venv は作業ディレクトリ内に作成
- システム環境へのインストール禁止
- タスク完了後に削除

本スキルはこのルールの実装として位置づけられる。

## 10. アンチパターン

| パターン | 問題 | 代替 |
|---------|------|------|
| プラグインソースディレクトリ内に venv 作成 | バージョン管理対象に紛れ込み、ポータビリティ低下 | 作業領域内に作成 |
| システム Python に直接インストール | 環境汚染 | 必ず venv 経由 |
| アクティベート前提のスクリプト | 副作用残存・移植困難 | 直接 `python` 呼び出し |
| 依存バージョン無指定（再現性が必要な場面） | バージョン変動で挙動が変わる | バージョン固定 |

## 10.5 Python バージョン要件チェック

`setup_venv.ps1` は `-MinPythonVersion` パラメータで **最小 Python バージョン要件** を受け付ける:

```powershell
pwsh -NoProfile -File "$env:CLAUDE_PLUGIN_ROOT/references/scripts/setup/setup_venv.ps1" `
  -WorkDir <work_dir> [-RequirementsPath <path>] [-MinPythonVersion <ver>]
```

例: Python 3.10 以上を要求する場合

```powershell
pwsh -NoProfile -File "$env:CLAUDE_PLUGIN_ROOT/references/scripts/setup/setup_venv.ps1" `
  -WorkDir "$WorkDir" -RequirementsPath "$ReqPath" -MinPythonVersion "3.10"
```

要件を満たさない場合はエラー終了し、ユーザに pyenv 等での切替を案内する。要件未指定時はチェックをスキップする。

## 11. 検証コマンド

setup 直後の確認:

```bash
"${VENV_DIR}/Scripts/python" --version
"${VENV_DIR}/Scripts/python" -m pip list
"${VENV_DIR}/Scripts/python" -c "import {package}; print({package}.__version__)"
```
