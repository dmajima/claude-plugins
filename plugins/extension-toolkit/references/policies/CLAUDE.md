# policies/

拡張要素の作成・レビュー・公開において従うべき **制約・禁止ルール** の正典（SSOT）を管理する。

## ファイル一覧

| ファイル | 内容 |
|---------|------|
| [`ai-readability.md`](ai-readability.md) | AI 可読性の記述指針（決定的言語・条件表・否定明示等） |
| [`argument-policy.md`](argument-policy.md) | コマンド引数・`$ARGUMENTS` の設計ポリシー |
| [`claude-md-policy.md`](claude-md-policy.md) | CLAUDE.md の配置・コンテンツ要件（本ポリシー自身） |
| [`commit-granularity.md`](commit-granularity.md) | コミット粒度・分割ルール |
| [`conventions-general.md`](conventions-general.md) | 共通規約・禁止事項（ファイル種別分離・ADR 運用等） |
| [`conventions-naming.md`](conventions-naming.md) | 命名規約（kebab-case・description・frontmatter） |
| [`conventions-structure.md`](conventions-structure.md) | ディレクトリ構造規約（プラグイン直下・スキル直下・references/） |
| [`dependencies-policy.md`](dependencies-policy.md) | プラグイン依存関係の宣言・解決ルール |
| [`license-policy.md`](license-policy.md) | MIT ライセンス配備ポリシー（ADR-029） |
| [`path-portability.md`](path-portability.md) | ポータブルパス記法（絶対パス・環境変数禁止） |
| [`readme-policy.md`](readme-policy.md) | README.md の必須セクション・記述ルール |
| [`scripts-policy.md`](scripts-policy.md) | スクリプト配置・実行ポリシー（ADR-024/025） |
| [`self-containment.md`](self-containment.md) | 自己完結性ポリシー（外部環境依存の禁止） |
| [`state-files.md`](state-files.md) | 状態ファイル形式のポリシー |
| [`versioning.md`](versioning.md) | バージョニングルール（SemVer・1 コミット 1 更新） |

## 利用ルール

- ポリシーファイルは **SSOT**（唯一の情報源）である。他ファイルからはリンクで参照し、内容をコピーしない
- 新規ポリシーを追加する前に `architecture/` に ADR を追記する
- ポリシーの変更時は、参照元（SKILL.md・guides・checklists）の整合性を確認する
- 各ファイルは「制約・禁止」に特化する。設計指針は `guides/`、検証項目は `checklists/` に分離する
