# プラグイン対象チェックリスト

`.claude-plugin/plugin.json` を含むディレクトリを対象とするチェック項目。`common.md` の項目および含有要素ごとの個別ファイル（`skill.md` / `command.md` / `agent.md` / `hook.md` / `readme.md`）と併用すること。

## P-1. ディレクトリ構造（厳格・許可リスト運用）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| P-1-1 | Critical | プラグイン直下に `.claude-plugin/plugin.json`（必須）が存在する | [conventions.md](../../../references/policies/conventions-structure.md) 節 2.1 |
| P-1-2 | High | プラグイン直下に `README.md`（必須）が存在する | 同上 |
| P-1-3 | High | プラグイン直下のディレクトリ・ファイルが許可リスト（`.claude-plugin/` / `README.md` / `LICENSE` (ADR-029) / `commands/` / `skills/` / `agents/` / `hooks/` / `mcp/` / `references/` / `assets/` (ADR-030)）に含まれる | 同上 |
| P-1-4 | High | プラグイン直下に `scripts/` ディレクトリが存在しない（ADR-025 違反検知。実スクリプトは `references/scripts/` に集約） | [conventions.md](../../../references/policies/conventions-structure.md) 節 2.3 / [scripts-policy.md](../../../references/policies/scripts-policy.md) |
| P-1-5 | High | プラグイン直下に `teams/` `templates/` `shared/` `common/` `lib/` `docs/` 等の禁止ディレクトリが存在しない（`references/` 配下に集約） | [conventions.md](../../../references/policies/conventions-structure.md) 節 2.3 |
| P-1-6 | High | 許可リスト外のエントリを追加する場合、新 ADR がある（`architecture-decisions.md` で明示） | [conventions.md](../../../references/policies/conventions-structure.md) 節 2.4 |

## P-2. plugin.json

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| P-2-1 | Critical | `plugin.json` が JSON valid（パース可能） | [validation-rules.md](../../../references/checklists/validation-rules.md) 節 1 |
| P-2-2 | High | `plugin.json` の `name` がプラグインディレクトリ名と完全一致 | 同 節 2.2 |
| P-2-3 | Medium | `plugin.json` の `description` が 80 文字以内 | [description-guide.md](../../../references/guides/description-guide.md) 節 2 |
| P-2-4 | Medium | `plugin.json` の `description` が主目的 1 つに焦点を絞っている（機能リストではない） | 同上 |
| P-2-5 | High | `plugin.json` に `version` フィールドが存在し、SemVer (`x.y.z`) 形式 | [versioning.md](../../../references/policies/versioning.md) 節 1 / 10 |

## P-3. 依存関係（dependencies）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| P-3-1 | High | 必須依存が `plugin.json` の `dependencies` で宣言されている（README のみへの記載は禁止） | [dependencies-policy.md](../../../references/policies/dependencies-policy.md) 節 1 / 10 |
| P-3-2 | High | クロスマーケットプレイス依存に `marketplace` フィールドが含まれる | 同 節 2.3 |
| P-3-3 | High | クロスマーケットプレイス依存先のマーケットプレイス側 `allowCrossMarketplaceDependenciesOn` に登録されている | 同 節 3.2 / 8 |
| P-3-4 | Medium | `version` 範囲が semver 構文（`~1.2.0` `^1.0.0` `>=1.0.0` 等）に従う、または省略 | 同 節 6 |
| P-3-5 | High | 厳密一致 (`"1.2.3"`) でハードコードしていない（バグ修正で壊れる） | 同 節 10 |

## P-4. 含有要素の検証（種別別）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| P-4-1 | High | 含有スキルが `skill-target.md` チェックリスト全項目を通過 | [skill-target.md](skill-target.md) |
| P-4-2 | High | 含有コマンドが `command.md` チェックリスト全項目を通過 | [command.md](command.md) |
| P-4-3 | High | 含有エージェントが `agent.md` チェックリスト全項目を通過 | [agent.md](agent.md) |
| P-4-4 | High | 含有フックが `hook.md` チェックリスト全項目を通過 | [hook.md](hook.md) |
| P-4-5 | High | プラグイン README が `readme.md` チェックリスト全項目を通過 | [readme.md](readme.md) |

## P-5. プラグイン直下 references/scripts/setup/（Python 利用時）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| P-5-1 | High | プラグインに `.py` ファイルが 1 つ以上あり、標準ライブラリ以外の `import` を含む場合、`references/scripts/setup/setup_venv.sh` が存在する | [scripts-policy.md](../../../references/policies/scripts-policy.md) 節 5.1 / ADR-024 |
| P-5-2 | High | 同上で `references/scripts/setup/teardown_venv.sh` が存在する | 同上 |
| P-5-3 | High | 同上で `references/scripts/setup/requirements.txt` が存在し、全スキルの依存をマージしている | 同上 |
| P-5-4 | High | スキルごとの個別 `requirements.txt` が存在しない | 同 節 5.2 |
| P-5-5 | High | スキル直下に `references/scripts/setup/setup_venv.sh` 等の重複設置がない | 同上 |

## P-6. 移管シナリオ（既存プラグイン化時）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| P-6-1 | Critical | 移管シナリオで元ファイル（移管元のスキル / コマンド / エージェント / フック）が無傷（git diff で削除のみ確認） | [validation-rules.md](../../../references/checklists/validation-rules.md) 節 2.2 |
| P-6-2 | Critical | 移管後の `~/.claude/settings.json` が改変されていない | 同上 |

## P-7. シークレット混入（プラグイン全体）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| P-7-1 | Critical | プラグイン配下に `.env` `*.pem` `*.key` `id_rsa` `credentials.json` `secrets.json` 等のシークレットファイルが含まれない | [validation-rules.md](../../../references/checklists/validation-rules.md) 節 2.2 |
| P-7-2 | Critical | コード・コメント内に API キー・トークン・パスワードらしい文字列が含まれない | [marketplace-publish の secret-scan.md](../../marketplace-publish/references/secret-scan.md) |

## P-8. レビューエージェント並列起動（プラグインレビュー時）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| P-8-1 | High | `plugin-review-team`（フック含有 6 名 / 非含有 5 名）または等価のフォールバック構成で並列起動された | [team-selection.md](../team-selection.md) / [plugin-review-team.md](../../../references/teams/plugin-review-team.md) |
| P-8-2 | High | フック含有時に `security-engineer`（または同等のフォールバック）が必須メンバーに含まれている | [review-perspectives.md](../review-perspectives.md) 節「観点網羅の原則」 |
| P-8-3 | Medium | description 観点は `description-trigger-reviewer` を **チーム外で単独並列起動** している | [agent-utilization.md](../../../references/guides/agent-utilization.md) 節 5.4 |
| P-8-4 | High | `architect` / `implementation-engineer` / `security-engineer` 不在時のフォールバックが明示されている（同梱版利用 or `general-purpose` を専門性プロンプトで起動） | [plugin-review-team.md](../../../references/teams/plugin-review-team.md) |

## P-8.5. references/ の CLAUDE.md（必須）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| P-8.5-1 | High | `references/` ディレクトリが存在する場合、`references/CLAUDE.md` が配置されている | [claude-md-policy.md](../../../references/policies/claude-md-policy.md) 節 2 |
| P-8.5-2 | High | `CLAUDE.md` に「目的と範囲」「原則」「ナビゲーション」セクションが含まれる | 同 節 3 |
| P-8.5-3 | High | `references/README.md` に「人間向け資料であり Claude エージェント動作では参照しない」旨の記載がある | 同 節 1 / [readme-policy.md](../../../references/policies/readme-policy.md) |
| P-8.5-4 | Medium | `CLAUDE.md` が 200 行以下で、詳細ルールを直接記載せずポリシーファイルへの参照で構成されている | [claude-md-policy.md](../../../references/policies/claude-md-policy.md) 節 4 |

## P-9. SSOT 参照の正確性

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| P-9-1 | High | プラグイン内ドキュメントの相互参照（`references/` ↔ `skills/{name}/SKILL.md` 等）がすべて到達可能 | [completion-checklist.md](../../../references/checklists/completion-checklist.md) 節 2.3 |
| P-9-2 | Medium | SKILL.md / 各 references / README から参照される SSOT が `extension-toolkit/references/` 配下に集約されている（ADR-002） | [conventions.md](../../../references/policies/conventions-structure.md) 節 4 |

## P-10. フック（hooks/hooks.json）プラグイン同梱時

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| P-10-1 | Critical | `hooks/hooks.json` が JSON valid | [validation-rules.md](../../../references/checklists/validation-rules.md) 節 2.6 |
| P-10-2 | High | フックスクリプトが `references/scripts/hooks/` 配下に配置されている（ADR-025） | [scripts-policy.md](../../../references/policies/scripts-policy.md) 節 9 |
| P-10-3 | High | PreToolUse 警告型フックが exit 0（fail-open）で動作する | [architecture-decisions.md](../../../references/architecture/decisions-001-010.md) ADR-026 |
| P-10-4 | High | Stop フックが git 利用不可・リポジトリ外で無音 exit 0 | 同上 |
| P-10-5 | High | `.claude/.local/` `.git/` `/tmp/` 配下を無条件で通過する除外ロジックを持つ | 同上 |
| P-10-6 | Critical | フック含有時、`hook-security-team` または等価構成での独立レビューを実施した | [team-selection.md](../team-selection.md) |
