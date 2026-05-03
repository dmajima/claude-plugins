# エージェント単体定義チェックリスト

`agents/{name}.md` 単体（プラグイン同梱・グローバル配置のいずれも）を対象とするチェック項目。`common.md` の項目と併用すること。

## A-1. ファイル名・配置

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| A-1-1 | High | ファイル名が kebab-case + `.md`（例: `code-reviewer.md`） | [conventions.md](../../../references/conventions.md) 節 1 |
| A-1-2 | High | プラグイン同梱なら `plugins/{plugin}/agents/{name}.md`、グローバルなら `~/.claude/agents/{name}.md` | 同 節 2.1 |

## A-2. frontmatter 必須項目

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| A-2-1 | Critical | frontmatter（YAML）が valid（パース可能） | [validation-rules.md](../../../references/validation-rules.md) 節 1 |
| A-2-2 | High | `name` フィールドが存在し、ファイル名（拡張子なし）と完全一致 | 同 節 2.4 |
| A-2-3 | High | `description` フィールドが存在する | 同上 |
| A-2-4 | High | `model` フィールドが存在する（例: `sonnet` / `opus` / `haiku`） | 同上 |
| A-2-5 | High | `tools` フィールドが存在し、許可ツールのカンマ区切りリスト | 同上 |

## A-3. description（AI トリガー判定）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| A-3-1 | High | 専門領域が明示されている | [description-guide.md](../../../references/description-guide.md) 節 5 / 6.2 |
| A-3-2 | High | 評価観点（何を見るか）が含まれている | 同上 |
| A-3-3 | High | 起動条件（いつ呼ばれるか）が含まれている | 同上 |
| A-3-4 | Medium | 改行が含まれない（YAML 単一行） | 同上 |

## A-4. 必須セクション

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| A-4-1 | High | `## ロール定義`（1〜3 文の役割記述）が存在する | [conventions.md](../../../references/conventions.md) 節 7 |
| A-4-2 | High | `## 専門性`（専門領域 / 評価軸 / 参照する外部知識）が存在する | 同上 |
| A-4-3 | High | `## 評価観点`（3 項目以上のチェックリスト）が存在する | 同上 / [validation-rules.md](../../../references/validation-rules.md) 節 2.4 |
| A-4-4 | High | `## 出力フォーマット`（Critical / High / Medium / Low / 総合判定の構造）が定義されている | 同上 |
| A-4-5 | Medium | `## プロンプトテンプレート`（起動時に渡すプロンプトのひな形）が存在する | 同上 |

## A-5. 出力フォーマットの整合性

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| A-5-1 | High | 出力フォーマットが Critical / High / Medium / Low / Suggestion + 総合判定（APPROVE / CONDITIONAL_APPROVE / REJECT）の構造に従う | [review-perspectives.md](../review-perspectives.md) 節「総合判定ルール」 |

## A-6. tools フィールドの最小権限

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| A-6-1 | Medium | `tools` が役割に必要な最小限のツールのみを許可している（例: レビュー専門家は Read, Grep, Glob のみ） | プラグイン同梱エージェント（`plugin-structure-reviewer.md` 等）の前例 |

## A-7. 重複・差別化

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| A-7-1 | High | 既存エージェント（プラグイン同梱 + グローバル）と役割が重複していない、または差別化点が明示されている | [review-perspectives.md](../review-perspectives.md) 節 4 |

## A-8. レビューエージェント並列起動（エージェント単体定義レビュー時）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| A-8-1 | High | 専用チームなし、個別 3 名（`plugin-structure-reviewer` / `description-trigger-reviewer` / `architect`）並列起動された | [review-perspectives.md](../review-perspectives.md) 節 4 / [team-selection.md](../team-selection.md) |

## A-9. プロンプトテンプレートの妥当性

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| A-9-1 | Medium | プロンプトテンプレート内の `{{変数名}}` が利用側でわかる名前になっている | [conventions.md](../../../references/conventions.md) 節 7 |
| A-9-2 | Medium | プロンプトテンプレートに「参照すべき規約」「出力フォーマット」が含まれている | 同上 |
