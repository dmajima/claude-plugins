# references/templates/

## 目的

対象プロジェクトへ配置するドキュメント雛形（SSOT）。`harness-init`（コード解析ベースの初期構築）・`harness-define`（spec-first の仕様先行作成）・`harness-update`（新規ドキュメント作成）が共用する。

## ファイル一覧

| ファイル | 生成先（対象プロジェクト） |
|---------|--------------------------|
| [claude-md-root.md](claude-md-root.md) | `.claude/CLAUDE.md` |
| [claude-md-references.md](claude-md-references.md) | `.claude/references/CLAUDE.md` |
| [claude-md-folder.md](claude-md-folder.md) | 各サブフォルダの `CLAUDE.md` |
| [requirement.md](requirement.md) | `references/requirements/*.md`（任意フォルダ。spec-first 運用時のみ） |
| [spec.md](spec.md) | `references/specs/*.md` |
| [system-design.md](system-design.md) | `references/system-designs/*.md` |
| [flow.md](flow.md) | `references/flows/*.md` |
| [environment.md](environment.md) | `references/environments/*.md` |
| [convention.md](convention.md) | `references/conventions/*.md` |
| [architecture.md](architecture.md) | `references/architecture/*.md` |
| [adr.md](adr.md) | `references/decisions/ADR-NNN_*.md` |
| [glossary.md](glossary.md) | `references/glossary.md` |

## 利用ルール

1. **雛形から生成する**: 対象プロジェクトのドキュメントは必ず対応する雛形から作成する（セクションの欠落を防ぐ）
2. **`{...}` プレースホルダは全置換する**: 生成物に未置換のまま残さない
3. **frontmatter の構成を維持する**: `title` / `sources` / `related` / `updated` と任意の `status` の構成を崩さない（規則は [../structure-spec.md](../structure-spec.md) 節 5・5.2。`status` は spec-first 生成時のみ付与し、code-first 生成時は行ごと削除する）
4. **該当情報がない節は `TODO:` を残す**: 推測で埋めない。雛形内に削除指示がある節（「なければ削除」等）はその指示に従う
5. **構造変更は structure-spec.md が先**: 雛形の見出し・frontmatter 構造を変える場合は [../structure-spec.md](../structure-spec.md) を先に更新し、雛形を追随させる

## 雛形内の相対リンクについて

雛形本文の相対リンク（`specs/CLAUDE.md`、`../specs/{対応する仕様書}.md` 等）は **生成先（対象プロジェクトの `.claude/` 配下）で解決されることを意図** している。本ディレクトリからは解決できないが設計上の意図であり、リンク切れとして扱わない。

## 関連フォルダ

| フォルダ | 関係 |
|---------|------|
| [../](../) | 生成物の構成仕様（`structure-spec.md`）・同期仕様（`sync-spec.md`）の格納元 |
| [../scripts/](../scripts/) | 同期状態を検査するフックスクリプト |
