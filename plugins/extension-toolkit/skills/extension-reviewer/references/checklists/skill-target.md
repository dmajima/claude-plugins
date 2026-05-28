# スキル対象チェックリスト

`SKILL.md` を含むディレクトリ（`plugins/{plugin}/skills/{skill}/` または単体スキル）を対象とするチェック項目。`common.md` の項目と併用すること。

## S-1. ディレクトリ構造（厳格・許可リスト運用）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| S-1-1 | High | スキル直下に `SKILL.md`（必須）が存在する | [conventions.md](../../../references/conventions.md) 節 3.1 |
| S-1-2 | High | スキル直下に `README.md`（必須）が存在する | 同上 |
| S-1-3 | High | スキル直下のディレクトリ・ファイルが許可リスト（`SKILL.md` / `README.md` / `references/` / `agents/` / `evals/` / `assets/` (ADR-030)）に含まれる | 同上 |
| S-1-4 | High | スキル直下に `scripts/` ディレクトリが存在しない（ADR-025 違反検知） | [conventions.md](../../../references/conventions.md) 節 3.3 / [scripts-policy.md](../../../references/scripts-policy.md) |
| S-1-5 | High | スキル直下に `tests/` `spec/` `docs/` `notes/` 等の禁止ディレクトリが存在しない | [conventions.md](../../../references/conventions.md) 節 3.3 |
| S-1-6 | High | 動作分岐があるのに `evals/` が省略されていない | [eval-guide.md](../../../references/eval-guide.md) 節 1 |
| S-1-7 | High | スキル直下 `references/scripts/setup/setup_venv.sh` 等の venv 関連スクリプトが存在しない（プラグイン直下に集約・ADR-024、PowerShell 統一） | [scripts-policy.md](../../../references/scripts-policy.md) 節 5.2 |
| S-1-8 | Medium | スキルごとの個別 `requirements.txt` を作っていない（プラグイン直下に統合・ADR-024） | 同上 |

## S-2. SKILL.md の制約

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| S-2-1 | High | `SKILL.md` が 200 行以下 | [conventions.md](../../../references/conventions.md) 節 3.5 |
| S-2-2 | High | frontmatter `name` がスキルディレクトリ名と完全一致 | 同上 |
| S-2-3 | Critical | frontmatter（YAML）が valid（パース可能） | [validation-rules.md](../../../references/validation-rules.md) 節 1 |
| S-2-4 | High | 必須セクションがすべて存在する: `## 責務` / `## 責務外` / `## トリガー条件` / `## 前提` / `## 実行モード判定` / `## 実行フロー` / `## 重要な制約` / `## 参照` | [ai-readability.md](../../../references/ai-readability.md) 節 5 |
| S-2-5 | Medium | 内容粒度が「概要・トリガー条件・基本フロー概要のみ」になっており、詳細は `references/` に分離されている | [conventions.md](../../../references/conventions.md) 節 3.5 |

## S-3. description（5W1H + 文字数）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| S-3-1 | High | **What**: 何をするスキルかが 1 文で含まれる | [description-guide.md](../../../references/description-guide.md) 節 3.1 |
| S-3-2 | High | **Where**: 対象成果物（ファイル / ディレクトリ）が明示されている | 同上 |
| S-3-3 | High | **When（日本語）**: トリガーフレーズ例 3 つ以上が具体的に列挙されている | 同上 |
| S-3-4 | High | **When（英語）**: `Use when ...` 句が含まれる | 同上 |
| S-3-5 | High | **Why**: `SKIP when ...` と関連スキル名が明示されている（責務外明示） | 同上 |
| S-3-6 | High | 文字数 300 文字以内（例外を主張する場合は 700 字以内 + SKILL.md 本文の例外注記必須） | [description-guide.md](../../../references/description-guide.md) 節 3.3 |
| S-3-7 | Medium | 150 文字未満になっていない（短すぎるとトリガー精度低下） | 同上 |
| S-3-8 | Medium | 装飾語（「包括的」「網羅的」「効率的」等）の冗長表現がない | 同上 |
| S-3-9 | Medium | ADR 番号・内部用語の羅列がない | 同上 |
| S-3-10 | High | 改行（YAML 単一行違反）が含まれていない | 同上 |

## S-4. references/ 配下の構造（緩い）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| S-4-1 | Medium | 業務単位ごとに分割されている（`procedures.md` `setup.md` `rules.md` 等） | [conventions.md](../../../references/conventions.md) 節 4.3 |
| S-4-2 | Medium | テンプレートファイルが `references/template/` 配下に配置されている（複数種別の場合はサブフォルダで細分化） | [conventions.md](../../../references/conventions.md) 節 4.3 / 8 |
| S-4-3 | Medium | `references/` 配下のファイル名が kebab-case + 用途名 | [conventions.md](../../../references/conventions.md) 節 1 |

## S-5. references/scripts/ 配下の構造（推奨例 + 一部禁止）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| S-5-1 | Medium | 業務単位サブフォルダで分割されている（`input/` `output/` `checks/` `helpers/` 等） | [conventions.md](../../../references/conventions.md) 節 5.2 |
| S-5-2 | Medium | 拡張子別サブフォルダ（`py/` `sh/` 等）を使っていない | 同上 |
| S-5-3 | Medium | `knowledge/` `lib/` `bin/` 等の禁止命名がない | 同上 |
| S-5-4 | High | スキル直下 `references/scripts/setup/` に Python venv 関連スクリプトを置いていない（プラグイン直下に集約・ADR-024） | [scripts-policy.md](../../../references/scripts-policy.md) 節 5.2 |

## S-6. インラインスクリプト禁止（ADR-025）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| S-6-1 | High | `SKILL.md` / `references/` の md ファイル内に 6 行以上のフェンス付きコードブロック（実行用）がない | [scripts-policy.md](../../../references/scripts-policy.md) 節 3.1 |
| S-6-2 | High | 制御構造（`if` / `for` / `while` / `function`）を含む 5 行以上のインラインスクリプトがない | 同上 |
| S-6-3 | Medium | 実行用スクリプトは `references/scripts/{業務}/` に切り出され、md には呼び出し例（5 行以下）のみ | 同上 |
| S-6-4 | Low | 設定ファイル例・出力例・ディレクトリ構造図はインライン残存可（[scripts-policy.md](../../../references/scripts-policy.md) 節 6） | 同上 |

## S-7. パスポータビリティ（自己参照）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| S-7-1 | High | スキル自身のスクリプト参照は `${CLAUDE_SKILL_DIR}/...` を使う | [path-portability.md](../../../references/path-portability.md) 節 1 |
| S-7-2 | High | プラグインルート参照は `${CLAUDE_PLUGIN_ROOT}/...` を使う | 同上 |
| S-7-3 | High | `.claude/skills/{name}/` のハードコードがない | 同上 |

## S-8. agents/（プラグイン配布時）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| S-8-1 | High | `agents/` ディレクトリの重複理由による削除が行われていない（プラグイン配布先環境のため保持必須） | [conventions.md](../../../references/conventions.md) 節 3.3 |

## S-9. evals/（動作分岐ありの場合）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| S-9-1 | High | 動作分岐がある場合 `evals/` が存在する | [eval-guide.md](../../../references/eval-guide.md) 節 1 |
| S-9-2 | High | `evals/README.md` が存在し、ケース一覧テーブルがある | 同 節 6 |
| S-9-3 | High | 各ケースが `case-{2 桁番号}_{snake_case}.md` 形式で命名されている | [conventions.md](../../../references/conventions.md) 節 1 |
| S-9-4 | High | 各ケースに「入力 / 期待動作 / 期待出力 / 分岐の根拠 / 関連ケース」が含まれる | [eval-guide.md](../../../references/eval-guide.md) 節 3 |
| S-9-5 | High | 対話モード × 非対話モードの両方がケース化されている | 同 節 4 |
| S-9-6 | High | 主要分岐の各ブランチが 1 ケース以上カバーされている | 同上 |
| S-9-7 | High | エラー系（既知失敗パス: 命名衝突・前提不足・対象不在等）がカバーされている | 同上 |
| S-9-8 | High | 重大度の異なる結果（APPROVE / CONDITIONAL_APPROVE / REJECT 系）の代表ケースが揃う | 同上 |
| S-9-9 | Medium | 1 ケース 1 ファイル原則に違反していない | 同 節 8 |
| S-9-10 | Medium | 期待動作の曖昧記述（「適切に」「うまく」等）がない | 同上 |
| S-9-11 | High | ケース番号と `evals/README.md` のケース一覧が同期している | 同上 |

## S-10. README.md（人間向け）

詳細は [readme.md](readme.md) を参照。スキルの README も同チェックリストを適用する。

## S-11. レビューエージェント並列起動（スキルレビュー時）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| S-11-1 | High | `skill-review-team`（3 名: `plugin-structure-reviewer` / `implementation-engineer` / `evals-coverage-reviewer`）または等価のフォールバック構成で並列起動された | [team-selection.md](../team-selection.md) / [skill-review-team.md](../../../references/teams/skill-review-team.md) |
| S-11-2 | Medium | description 観点は `description-trigger-reviewer` を **チーム外で単独並列起動** している | [agent-utilization.md](../../../references/agent-utilization.md) 節 5.4 |

## S-12. SSOT 参照の正確性

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| S-12-1 | High | SKILL.md 「## 参照」セクションのリンクがすべて到達可能（broken link なし） | [completion-checklist.md](../../../references/completion-checklist.md) 節 2.3 |
| S-12-2 | Medium | 詳細手順が `references/procedures.md`、環境構築が `references/setup.md` に分離されている（該当時） | [conventions.md](../../../references/conventions.md) 節 4.3 |
