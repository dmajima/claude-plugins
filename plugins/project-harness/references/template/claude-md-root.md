# {project-name}

{プロジェクトの目的・提供価値を 1〜3 文で記載}

## 技術スタック

| レイヤ | 技術 | バージョン |
|-------|------|-----------|
| {言語} | {例: C# / TypeScript} | {検出したバージョン} |
| {フレームワーク} | {例: ASP.NET Core / React} | {バージョン} |
| {データストア} | {例: SQL Server / PostgreSQL} | {バージョン} |
| {その他} | {ビルドツール・主要ライブラリ} | {バージョン} |

## 主要コマンド

| 用途 | コマンド |
|------|---------|
| ビルド | `{build-command}` |
| テスト | `{test-command}` |
| リント | `{lint-command}` |
| ローカル起動 | `{run-command}` |

詳細な環境情報・検証手順は [.claude/references/environments/](references/environments/CLAUDE.md) を参照。

## リポジトリ構成（概要）

```text
{主要ディレクトリのツリー（3 階層まで・簡潔に）}
```

## ドキュメントハーネス

仕様・設計・規約などの詳細情報は `.claude/references/` 配下に整理されている。
**実装・修正・調査の前に [references/CLAUDE.md](references/CLAUDE.md) で該当ドキュメントを確認すること。**

| 知りたいこと | 参照先 |
|-------------|-------|
| 機能の仕様・業務ルール | `references/specs/` |
| 実装の詳細設計 | `references/system-designs/` |
| 画面の場所・アクセス手順 | `references/flows/` |
| ビルド・テスト・検証方法 | `references/environments/` |
| コーディング規約 | `references/conventions/` |
| システム構成・データモデル | `references/architecture/` |
| 設計判断の背景 | `references/decisions/` |
| ドメイン用語 | `references/glossary.md` |

## 変更時のルール

- コード変更がドキュメントの記載内容に影響する場合、`/project-harness:update` でハーネスへ反映する
- 変更を検証せずに完了報告しない（検証コマンドは `references/environments/` 参照）
