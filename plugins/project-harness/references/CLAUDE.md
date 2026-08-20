# project-harness プラグイン references 索引

`project-harness` プラグイン内の共有参照資料の索引。スキル（`harness-init` / `harness-update`）と
フックはここに列挙されたファイルを参照する。

## 原則

- ハーネス構成（フォルダ定義・frontmatter 規則・命名・アーカイブ規則）の単一情報源は `structure-spec.md` とし、判断が割れたら必ずこちらへ戻る
- 同期の仕組み（state スキーマ・差分検出・鮮度フック挙動）の単一情報源は `sync-spec.md` とする
- 対象プロジェクトへ配置するドキュメントは必ず `template/` の雛形から生成する（その場の独自フォーマット作成禁止）
- 対象プロジェクトに書く内容はソース・実動作の根拠に基づく。確認できない内容は `TODO:` 明示（捏造禁止）
- 対象プロジェクトの既存ファイルは無確認で変更・削除しない
- スクリプト（`scripts/`）はフェイルオープン設計を維持する（失敗してもセッションをブロックしない）

## ファイル一覧

| パス | 内容 | 主な参照元 |
|------|------|-----------|
| [structure-spec.md](structure-spec.md) | 対象プロジェクトに構築する `.claude` ハーネス構成の仕様（SSOT） | harness-init / harness-update |
| [sync-spec.md](sync-spec.md) | 同期状態管理・差分検出・鮮度検知フックの仕様（SSOT） | harness-init / harness-update / SessionStart フック |
| `template/` | 対象プロジェクトへ配置するドキュメント雛形 | harness-init / harness-update |
| `scripts/hooks/freshness_check.sh` | SessionStart 鮮度検知フックスクリプト | hooks/hooks.json |

## template/ 配下

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

## 編集ルール

- ハーネス構成（フォルダ定義・frontmatter 規則）を変える場合は `structure-spec.md` を先に更新し、テンプレート・スキルを追随させる
- 同期の仕組み（state スキーマ・検出フロー・フック挙動）を変える場合は `sync-spec.md` を先に更新する
- テンプレートのプレースホルダは `{...}` 記法で統一する
