# case-08 単独起動時の言語・FW 自己検出（O10 自己検出）

`language-profiles` 引数を受領しない単独起動で、本スキルが差分から言語・FW を自己検出し（language-detection.md の手順）、検出プロファイルを内部エージェントのプロンプトに適用するケース。オーケストレーターからの受領経路（case-07）ではなく、自己検出経路（O10 後段）を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "実装品質をレビューして"（`language-profiles` 引数なし） |
| 起動形態 | 単独（オーケストレーター不在・ユーザー直接起動） |
| 差分内容 | Python + Django の変更（`app/views.py` `app/models.py` 等の `.py` + リポジトリルートに `requirements.txt`（`django` 依存）・`pyproject.toml`。`language-profiles` は未受領） |

## 分岐の根拠

SKILL.md「入力（呼び出し時の引数）」表の「言語プロファイル」行「…未受領時は `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` で自己検出する（O10）」、SKILL.md「実行フロー」手順 1.5「`language-profiles` の適用観点プロファイルを確認し（未受領時は … language-detection.md で自己検出）…」、references/skill-rules-matrix.md O10（`language-profiles` 引数（未受領時は自己検出）に基づき観点プロファイルをエージェントプロンプトに含める）、`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション 4.5 手順 2（引数が無い場合（単独実行時）は language-detection.md の手順で自己検出する）、`${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` セクション 2〜3。

**既存ケースとの差別化**: case-07 は **オーケストレーターから `language-profiles` を受領した** 委譲経路（O10 前段・C# / .NET / EF Core）を検証するのに対し、本ケースは **引数を受領しない単独起動** で本スキルが自ら language-detection.md の手順を実行して言語・FW を確定する **自己検出経路**（O10 後段）を、別言語（Python / Django）で検証する。

## 期待動作

- `language-profiles` 引数が無いことを検知し、`${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` の手順で自己検出に切り替える（SKILL.md 実行フロー手順 1.5 / common-references.md セクション 4.5 手順 2 / O10）
- 差分拡張子 `.py` から Python を言語候補として列挙し、マーカーファイル `requirements.txt` / `pyproject.toml` を Glob・Read して依存に `django` があることを確認する（language-detection.md セクション 3 Step 1〜3。**マーカーを確認せず拡張子だけで FW を断定しない**）
- 検出結果から `languages/python.md`（主）+ `frameworks/python-web.md`（Django）を適用プロファイルに確定する（language-detection.md セクション 2.1 / 2.2）
- implementation-engineer / linter-static-analysis / performance-reviewer の各プロンプトに、common-references.md セクション 4.5 のテンプレートに従い、自己検出した python.md / python-web.md への参照指示を含める（O10）
- implementation-engineer は python.md 観点 3.1〜3.5・3.8、performance-reviewer は python.md 観点 3.6、linter-static-analysis は python.md セクション 6 の動的検証コマンド（`ruff check .` / `pytest` 等）を参照する（common-references.md セクション 4.5 のエージェント別主担当プロファイル表）
- オーケストレーター不在のため、本スキル自身で progress.md を作成・維持する（checklist.md O8）
- プロジェクト独自規約（存在すれば）が最優先で、プロファイルのデファクトはプロジェクト規約が無い項目のみに適用する（conventions-resolution.md の 5 段階解決）
- 検出されなかった言語・FW のプロファイルは適用しない（language-detection.md セクション 5 禁止事項）

## 関連ケース

- case-07: language-profiles 受領とエージェントへの適用（O10 前段・委譲経路）
- case-03: 単独実行・動的検証権限なし（同じ単独起動・progress.md 自スキル作成）
