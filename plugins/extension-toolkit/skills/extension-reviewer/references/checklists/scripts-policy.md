# スクリプトポリシーチェックリスト（Python 利用プラグイン向け）

ADR-024 / ADR-025 に従ったスクリプト配置・インラインスクリプト禁止のチェック項目。Python を利用するプラグインに適用する。`common.md` の項目と併用すること。

## SP-1. インラインスクリプト禁止（ADR-025）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| SP-1-1 | High | `references/`・`SKILL.md`・`README.md` 等の md ファイルに、6 行以上のフェンス付き実行コードブロック（`bash` / `python` / `sh` / `powershell` 等）がない | [scripts-policy.md](../../../references/scripts-policy.md) 節 3.1 |
| SP-1-2 | High | 制御構造（`if` / `for` / `while` / `function`）を含む 5 行以上のインラインスクリプトがない | 同上 |
| SP-1-3 | Medium | 引数を取る・複数責務を持つ・ヒアドキュメント・パイプチェーン 3 段以上を含むスクリプトがファイル化されている | 同上 |
| SP-1-4 | Medium | エラーハンドリング・例外処理を含むスクリプトがファイル化されている | 同上 |
| SP-1-5 | Low | 設定ファイル例・出力例・ディレクトリ構造図はインライン残存可（実行用ではない） | 同 節 6 |

## SP-2. 配置構造（2 階層）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| SP-2-1 | High | 実行可能スクリプトはすべて `references/scripts/{業務}/` 配下に配置されている | [scripts-policy.md](../../../references/scripts-policy.md) 節 2 |
| SP-2-2 | High | プラグイン直下 `scripts/` ディレクトリが存在しない（ADR-025） | [conventions.md](../../../references/conventions.md) 節 2.3 |
| SP-2-3 | High | スキル直下 `scripts/` ディレクトリが存在しない（ADR-025） | [conventions.md](../../../references/conventions.md) 節 3.3 |

## SP-3. プラグイン直下 references/scripts/setup/（ADR-024）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| SP-3-1 | High | プラグインに `.py` ファイルが 1 つ以上あり、標準ライブラリ以外の `import` を含む場合、`references/scripts/setup/setup_venv.sh` が存在する | [scripts-policy.md](../../../references/scripts-policy.md) 節 5.2 / ADR-024 |
| SP-3-2 | High | 同上で `references/scripts/setup/teardown_venv.sh` が存在する | 同上 |
| SP-3-3 | High | 同上で `references/scripts/setup/requirements.txt` が存在し、**全スキルの依存をマージ** している | 同上 |
| SP-3-4 | High | スキルごとの個別 `requirements.txt` が存在しない | 同上 |
| SP-3-5 | High | スキル直下 `references/scripts/setup/setup_venv.sh` 等の重複設置がない | 同上 |

## SP-4. venv のライフサイクル

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| SP-4-1 | High | venv 実体は `<work_dir>/.venv` にプラグイン単位で 1 つ作成され、複数スキルが共有する設計 | [scripts-policy.md](../../../references/scripts-policy.md) 節 5.4 |
| SP-4-2 | High | venv 内 python を直接呼ぶ運用（`<work_dir>/.venv/Scripts/python` の絶対参照）になっている | 同上 |
| SP-4-3 | High | スキル本体は構築・実行・撤去の 3 ステップのみを実施（venv 内部ロジックは setup スクリプト側で完結） | 同上 |

## SP-5. environment-setup-toolkit との関係

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| SP-5-1 | Medium | `environment-setup-toolkit` がプラグイン直下スクリプト呼び出しのオーケストレータ役に限定されている（自前 setup 実装を持たない） | [architecture-decisions.md](../../../references/architecture-decisions.md) ADR-024 |

## SP-6. 禁止命名（references/scripts/ 配下）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| SP-6-1 | Medium | `references/scripts/` 直下に `knowledge/` `lib/` `bin/` 等の禁止命名がない | [conventions.md](../../../references/conventions.md) 節 5.3 |
| SP-6-2 | Medium | 拡張子別サブフォルダ（`py/` `sh/` `ps1/` 等）を使っていない | 同上 |

## SP-7. PowerShell からの直接 Python 起動禁止

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| SP-7-1 | High | 機械チェックスクリプトは **必ず Bash 経由 + venv 内 Python + JSON ファイル出力** で実施されている | [automated-checks.md](../automated-checks.md) |
| SP-7-2 | High | PowerShell から `python` を直接起動する記述（`pwsh -c "python ..."` 等）が含まれない | 同上 |
| SP-7-3 | Medium | `chcp 65001` / `[Console]::OutputEncoding=...` の手動切り替えが含まれない | 同上 |
| SP-7-4 | Medium | Python スクリプトから日本語を **stdout に書き出していない**（必ずファイルに書く） | 同上 |

## SP-8. 機械チェックでの違反検出

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| SP-8-1 | High | `run_checks.py` が md 内の 6 行以上のフェンス付きコードブロックを High 指摘として報告していない（=違反なし） | [scripts-policy.md](../../../references/scripts-policy.md) 節 7 |
| SP-8-2 | High | `run_checks.py` がトップレベル `scripts/` 配下を High 指摘として報告していない（=違反なし） | 同上 |
