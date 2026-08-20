# template/ 索引

対象プロジェクトへ配置するドキュメント雛形。`harness-init`（初期構築）・`harness-update`（新規ドキュメント作成）が使用する。
プレースホルダは `{...}` 記法で統一し、生成時に解析結果で置換する。

## 原則

- 雛形の構造（見出し・frontmatter）は `../structure-spec.md` の規則と一致させる（変更時は structure-spec.md を先に更新）
- frontmatter は `title` / `sources` / `related` / `updated` の 4 フィールド構成を崩さない
- 生成時に該当情報がない節は `TODO:` を残すか、雛形内の指示（「なければ削除」等）に従う

## ファイル一覧

| ファイル | 生成先（対象プロジェクト） |
|---------|--------------------------|
| `claude-md-root.md` | `.claude/CLAUDE.md` |
| `claude-md-references.md` | `.claude/references/CLAUDE.md` |
| `claude-md-folder.md` | 各サブフォルダの `CLAUDE.md` |
| `spec.md` | `references/specs/*.md` |
| `system-design.md` | `references/system-designs/*.md` |
| `flow.md` | `references/flows/*.md` |
| `environment.md` | `references/environments/*.md` |
| `convention.md` | `references/conventions/*.md` |
| `architecture.md` | `references/architecture/*.md` |
| `adr.md` | `references/decisions/ADR-NNN_*.md` |
| `glossary.md` | `references/glossary.md` |
