# コマンド対象チェックリスト

`commands/{name}.md` 単体を対象とするチェック項目。`common.md` の項目と併用すること。

## CMD-1. ファイル名と命名

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| CMD-1-1 | High | ファイル名が kebab-case + `.md`（例: `extension.md`） | [conventions.md](../../../references/conventions.md) 節 1 |
| CMD-1-2 | High | 配置が `plugins/{plugin}/commands/{name}.md`（プラグイン直下 `commands/`） | 同 節 2.1 |

## CMD-2. frontmatter `description`

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| CMD-2-1 | Critical | frontmatter（YAML）が valid（パース可能） | [validation-rules.md](../../../references/validation-rules.md) 節 1 |
| CMD-2-2 | Medium | `description` が 60 文字以内 | [description-guide.md](../../../references/description-guide.md) 節 4 |
| CMD-2-3 | Low | `description` がコマンドの効果 1 つに焦点を絞っている | 同上 |
| CMD-2-4 | Low | `description` 内に引数仕様を含めていない（`argument-hint` に集約） | 同上 |

## CMD-3. frontmatter `argument-hint`（ADR-023 必須化）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| CMD-3-1 | High | 引数を受け取るコマンド（本文に `$ARGUMENTS` を含む）に `argument-hint` が **必ず** 記載されている | [description-guide.md](../../../references/description-guide.md) 節 4.1 / ADR-023 |
| CMD-3-2 | Medium | `argument-hint` が 60 文字以内 | 同上 |
| CMD-3-3 | High | `argument-hint` に改行が含まれない（YAML 単一行） | 同上 |
| CMD-3-4 | Medium | 必須引数は `<...>`、省略可は `[...]`、フラグは `[--flag 値]` または `[--flag]` の表記規則に従う | 同 節 4.1.1 |
| CMD-3-5 | Critical | `argument-hint` の値が `[` `{` `&` `*` `?` `!` `\|` `>` `%` `@` 等の YAML 特殊文字で始まる場合、ダブルクォートで囲まれている（YAML パース失敗防止） | 同 節 4.1.3 |

## CMD-4. ルーティング（オーケストレータ型コマンドの場合）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| CMD-4-1 | High | ルーティング先スキルがすべて存在する | [validation-rules.md](../../../references/validation-rules.md) 節 2.3 |
| CMD-4-2 | Medium | ルーティング表が表形式で本文に記載されている（外部設定ファイルへの切り出し禁止・ADR-007） | [architecture-decisions.md](../../../references/architecture-decisions.md) ADR-007 |

## CMD-5. インラインスクリプト禁止（ADR-025）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| CMD-5-1 | High | コマンド本文内に 6 行以上のフェンス付きコードブロック（実行用）がない | [scripts-policy.md](../../../references/scripts-policy.md) 節 3.1 |
| CMD-5-2 | High | 制御構造（`if` / `for` / `while`）を含む 5 行以上のインラインスクリプトがない | 同上 |

## CMD-6. パスポータビリティ

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| CMD-6-1 | High | コマンド本文内のパスが `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_SKILL_DIR}` / 相対パス を使用している | [path-portability.md](../../../references/path-portability.md) |
| CMD-6-2 | High | ローカル絶対パスのハードコードがない | 同上 |

## CMD-7. レビューエージェント並列起動（コマンドレビュー時）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| CMD-7-1 | High | 専用チームなし、個別 4 名（`plugin-structure-reviewer` / `description-trigger-reviewer` / `implementation-engineer` / `security-engineer`）並列起動された | [review-perspectives.md](../review-perspectives.md) 節 3 |
| CMD-7-2 | Medium | 外部実行・危険操作を含まない場合、`security-engineer` を省略し 3 名構成にすることが許容される（理由必須） | 同上 |

## CMD-8. セキュリティ（実行コマンドの危険性）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| CMD-8-1 | Critical | 任意の `$ARGUMENTS` 値を `eval` / `$(...)` / バッククォートでシェル実行していない | [hook-security-team.md](../../../references/teams/hook-security-team.md)（コマンドインジェクション観点を準用） |
| CMD-8-2 | High | 動的データを文字列補間で `command` フィールドに埋め込まず、引数で安全に渡している | 同上 |
| CMD-8-3 | High | 削除・上書き等の破壊的操作はユーザ確認（AskUserQuestion）を経る | [user-interaction.md](../../../references/user-interaction.md) |
