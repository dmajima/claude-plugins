# フック対象チェックリスト

`hooks/hooks.json`（および `references/scripts/hooks/` 配下の実スクリプト）を対象とするチェック項目。`common.md` の項目と併用すること。

## H-1. ファイル配置

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| H-1-1 | High | フック設定ファイルが `hooks/hooks.json` または `settings.json` の `hooks` セクションに配置されている | [conventions.md](../../../references/conventions.md) 節 1 |
| H-1-2 | High | フック実スクリプトが `references/scripts/hooks/` 配下に配置されている（ADR-025） | [scripts-policy.md](../../../references/scripts-policy.md) 節 9 |
| H-1-3 | High | フック実スクリプトが `.ps1` で実装されている（`.sh` 残存は禁止、shell-preference.md） | [shell-preference.md](https://github.com/dmajima/claude-plugins) |

## H-2. JSON valid

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| H-2-1 | Critical | `hooks.json` が JSON valid（パース可能） | [validation-rules.md](../../../references/validation-rules.md) 節 2.6 |

## H-3. イベント名・matcher

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| H-3-1 | High | イベント名が正規（既知イベント: `PreToolUse` / `PostToolUse` / `Stop` / `UserPromptSubmit` / `SessionStart` 等） | 同上 |
| H-3-2 | High | PreToolUse / PostToolUse の matcher が正規表現として valid | 同上 |
| H-3-3 | Medium | timeout が指定されている | 同上 |

## H-4. command の安全性（コマンドインジェクション）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| H-4-1 | Critical | `command` フィールド内で動的データ（tool_input 等）を **文字列補間していない** | [hook-security-team.md](../../../references/teams/hook-security-team.md) 節「必須チェック観点」 |
| H-4-2 | Critical | `$(...)` / バッククォート（コマンド置換）の使用が必要最小限である | 同上 |
| H-4-3 | Critical | `eval` / `Invoke-Expression` を使っていない | 同上 |
| H-4-4 | High | 動的データが必要な場合は外部スクリプトに委譲し、引数として安全に受け渡されている | 同上 |
| H-4-5 | Critical | `command` にローカル絶対パスのハードコードがない（`${CLAUDE_PLUGIN_ROOT}` を使用） | [validation-rules.md](../../../references/validation-rules.md) 節 2.6 |
| H-4-6 | High | `command` は `pwsh -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/.../*.ps1"` 形式（`bash ...sh` は使わない） | [shell-preference.md](https://github.com/dmajima/claude-plugins) |

## H-5. PreToolUse 警告型フック（ADR-026）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| H-5-1 | High | PreToolUse Edit/Write/MultiEdit フックは **exit 0**（fail-open、ブロックしない） | [architecture-decisions.md](../../../references/architecture-decisions.md) ADR-026 |
| H-5-2 | High | `plugins/{name}/` 配下への直接編集を検知して、対応する `*-toolkit` スキル名を stderr に提示する | 同上 |
| H-5-3 | High | `.claude/.local/` `.git/` `/tmp/` 配下を無条件で通過する除外ロジックがある | 同上 |

## H-6. Stop フック（バージョン更新検証）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| H-6-1 | High | Stop フックは **exit 0**（fail-open） | 同上 |
| H-6-2 | High | git 利用不可・リポジトリ外で **無音 exit 0** | 同上 |
| H-6-3 | High | `plugin.json` の `version` が main ブランチから未更新の場合、stderr で警告を出す | 同上 |

## H-7. PreToolUse Bash（version 検証ラッパー、ADR-027）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| H-7-1 | High | `matcher: "Bash"` で `references/scripts/hooks/check_version_bump_on_commit.ps1` が登録されている | [architecture-decisions.md](../../../references/architecture-decisions.md) ADR-027 / [shell-preference.md](https://github.com/dmajima/claude-plugins) |
| H-7-2 | High | tool_input.command に `git commit` を含む場合のみ `check_version_bump.ps1` に委譲する | 同上 |
| H-7-3 | Medium | 非対象は exit 0 で即離脱（重い処理は git commit 検出時のみ実行） | 同上 |

## H-8. settings.json 既存エントリの保全

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| H-8-1 | Critical | `settings.json` への追加は既存エントリをマージで書き戻している（既存設定を破壊していない） | [validation-rules.md](../../../references/validation-rules.md) 節 2.6 |

## H-9. レビューエージェント並列起動（フックレビュー時）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| H-9-1 | High | `hook-security-team`（3 名: `security-engineer`（リード）/ `implementation-engineer` / `infrastructure-engineer`）または等価のフォールバック構成で並列起動された | [team-selection.md](../team-selection.md) / [hook-security-team.md](../../../references/teams/hook-security-team.md) |
| H-9-2 | High | リード `security-engineer` が脅威モデリング・コマンドインジェクション観点で評価している | 同上 |
| H-9-3 | High | 攻撃シナリオの相互検証ラウンドが最低 3 回実施されている | 同上 |

## H-10. セキュリティ指摘の取り扱い

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| H-10-1 | Critical | セキュリティ指摘（Critical / High）は必ずユーザ確認を経ている（`--auto-fix` でも対象外） | [SKILL.md](../../SKILL.md) 節 6 |
| H-10-2 | High | 自動修正の対象外として扱われている | 同上 |

## H-11. PowerShell 起動形態（shell-preference.md / 移行担保）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| H-11-1 | High | `hooks.json` の `command` が `pwsh -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/..."` 形式である | [shell-preference.md](https://github.com/dmajima/claude-plugins) |
| H-11-2 | High | `references/scripts/hooks/` 配下に `.sh` が残存していない（すべて `.ps1` へ移行済み） | 同上 |
| H-11-3 | High | `.ps1` 内で stdin / stdout / stderr が UTF-8 (no BOM) で扱われている | [console-encoding.md](https://github.com/dmajima/claude-plugins) |
| H-11-4 | Medium | PowerShell 経由で Python を呼ぶ場合、venv 内 Python の明示パス指定 + `python-encoding-mandatory.md` の必須3点セットを遵守 | [python-encoding-mandatory.md](https://github.com/dmajima/claude-plugins) |
| H-11-5 | High | `run_checks.py` の `check_no_bash_invocation` （automated-checks.md #12）が High 指摘として報告していない | [automated-checks.md](../automated-checks.md) #12 |

## H-12. shell フィールド明示（MANDATORY / shell-preference.md / 補強）

`pwsh -NoProfile -File ...` で書いていても、Claude Code 側の起動シェルが Git Bash の場合に
引数解釈・PATH 解決でエッジケースが発生しうる。各 hook エントリの `type: "command"` と
同階層に **`"shell": "powershell"`** を明示することで、PowerShell ホストでの起動を一義的に伝える。

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| H-12-1 | High | `hooks.json` の各 hook エントリに `"shell": "powershell"` が **明示** されている（`type: "command"` と同階層） | [hook-events.md](../../../../hook-toolkit/references/hook-events.md) 節「shell 指定（MANDATORY）」 |
| H-12-2 | High | `settings.json` の `hooks` セクションに追加するエントリも同様に `"shell": "powershell"` を明示している | 同上 |
| H-12-3 | Medium | `"shell"` の値が `"powershell"` または `"bash"` のいずれか（本マーケットプレイスは `"powershell"` のみ採用） | 同上 |
| H-12-4 | High | `run_checks.py` の `check_hook_shell_field` （automated-checks.md #13）が High 指摘として報告していない | [automated-checks.md](../automated-checks.md) #13 |
