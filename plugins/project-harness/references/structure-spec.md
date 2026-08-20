# .claude ハーネス構成仕様（SSOT）

`project-harness` プラグインが対象プロジェクトに構築・維持する `.claude` フォルダ構成の単一情報源。
`harness-init` / `harness-update` の両スキルはこの仕様に従って生成・更新を行う。

## 1. 目的（ハーネスエンジニアリング）

AI エージェントが対象プロジェクトで自律的・正確に働くための足場（ハーネス）を文書体系として整備する。

| 要素 | 役割 | 対応フォルダ |
|------|------|-------------|
| 地図 | プロジェクトの全体像・どこに何があるか | `CLAUDE.md` / `architecture/` / `specs/` / `flows/` |
| 検証手段 | 変更を自己検証するコマンド・手順 | `environments/` |
| ルール | 出力をプロジェクト標準に揃える規約 | `conventions/` |
| 判断履歴 | 既存判断の背景・用語の統一 | `decisions/` / `glossary.md` |
| 実装知識 | 仕様に対応する設計の詳細 | `system-designs/` |

## 2. ディレクトリ構成

```text
<target-repo>/.claude/
├── CLAUDE.md                  # プロジェクト概要・技術スタック（常時読込・簡潔に保つ）
└── references/
    ├── CLAUDE.md              # references/ 直下の一覧・用途・ドキュメント整理ルール
    ├── .sync-state.json       # 同期状態（sync-spec.md 参照）
    ├── specs/
    │   ├── CLAUDE.md          # 配下ファイルの一覧・用途
    │   └── *.md               # 仕様設計書
    ├── system-designs/
    │   ├── CLAUDE.md
    │   └── *.md               # 詳細設計書
    ├── flows/
    │   ├── CLAUDE.md
    │   └── *.md               # 画面位置・アクセス手順
    ├── environments/
    │   ├── CLAUDE.md
    │   └── *.md               # ビルド・テスト・起動・検証コマンド
    ├── conventions/
    │   ├── CLAUDE.md
    │   └── *.md               # コーディング規約・命名・配置・コミット/PR 規約
    ├── architecture/
    │   ├── CLAUDE.md
    │   └── *.md               # システム構成・モジュール依存・データモデル
    ├── decisions/
    │   ├── CLAUDE.md
    │   └── ADR-NNN_*.md       # 設計判断記録
    └── glossary.md            # ドメイン用語集（単一ファイル）
```

## 3. 各フォルダの定義

| フォルダ | 内容 | ファイル粒度 |
|---------|------|-------------|
| `specs/` | 画面遷移・画面構成・業務ルール・アプリ動作まで踏み込んだ仕様設計書 | 機能・画面単位で 1 ファイル |
| `system-designs/` | `specs/` の仕様に対応した詳細設計書。実装において詳細化すべき設計情報（クラス構成・処理フロー・データアクセス・例外方針） | 対応する spec 単位で 1 ファイル |
| `flows/` | アプリ・サイトの画面位置とアクセス手順（URL・ナビゲーション経路・到達前提条件・権限） | 業務フロー・導線単位で 1 ファイル |
| `environments/` | ビルド・テスト・リント・起動・デプロイのコマンドと手順、環境変数、ローカル環境構築、デバッグ方法 | 環境・用途単位（例: `local-dev.md` / `test.md` / `ci-cd.md`） |
| `conventions/` | コーディング規約・命名規則・ファイル配置規則・コミット / PR 規約 | 規約分類単位 |
| `architecture/` | システム構成図・モジュール依存関係・データモデル（mermaid 図解を推奨） | 視点単位（例: `overview.md` / `data-model.md`） |
| `decisions/` | ADR（Architecture Decision Record）。採用した技術・構造の背景と理由 | 判断 1 件 = 1 ファイル（`ADR-NNN_<slug>.md`、NNN は 001 からの連番） |
| `glossary.md` | ドメイン用語・ユビキタス言語の定義 | 単一ファイル |

## 4. CLAUDE.md 階層索引規則（段階的開示）

コンテキスト効率のため、情報は「常時読込される最小限の入口 → 必要時に辿る詳細」の階層で整理する。

| ファイル | 記載内容 | 制約 |
|---------|---------|------|
| `.claude/CLAUDE.md` | プロジェクト概要・技術スタック・主要コマンド要約・`references/` への案内 | セッション毎に常時読込されるため **100 行以内** を目安に簡潔に保つ。詳細は書かず `references/` へ誘導する |
| `references/CLAUDE.md` | フォルダ一覧・用途・ドキュメント整理ルール（どの情報をどこに置くか） | フォルダ単位の案内に留め、個別ファイルには踏み込まない |
| 各サブフォルダの `CLAUDE.md` | 配下ファイルの一覧・用途の表 | ファイル実体と一覧の一致を常に維持（`harness-update` が同期する） |

## 5. frontmatter 規則

`references/` 配下の各ドキュメント（`CLAUDE.md` と `.sync-state.json` を除く）は、先頭に以下の frontmatter を持つ。

```yaml
---
title: <ドキュメント名>
sources:
  - <対応するソースコードパスのグロブ（リポジトリルート相対）>
related:
  - <関連ドキュメントの references/ 相対パス（任意）>
updated: <YYYY-MM-DD>
---
```

| フィールド | 必須 | 用途 |
|-----------|------|------|
| `title` | 必須 | ドキュメント名（インデックス表と一致させる） |
| `sources` | 必須 | このドキュメントが対応するソースパスのグロブ。`harness-update` の差分検出キー。ソース対応がない文書（用語集等）は `[]` |
| `related` | 任意 | spec ↔ system-design ↔ flow の相互参照 |
| `updated` | 必須 | 最終更新日 |

## 6. 命名規則

| 対象 | 規則 | 例 |
|------|------|---|
| ドキュメントファイル | kebab-case | `login-screen.md` |
| ADR | `ADR-NNN_<slug>.md` | `ADR-001_use-postgresql.md` |
| spec と system-design の対応 | 同名を推奨 | `specs/login-screen.md` ↔ `system-designs/login-screen.md` |

## 6.1 アーカイブ規則

対応ソースが削除される等でドキュメントが現行仕様でなくなった場合、ユーザ承認のうえ以下のいずれかで整理する。

| 扱い | 動作 |
|------|------|
| 削除 | ファイルを削除し、所属フォルダの `CLAUDE.md` 索引から該当行を除去する |
| アーカイブ | 所属フォルダ内の `archive/` サブフォルダへ移動し、frontmatter の `sources` を `[]` に変更する。索引 `CLAUDE.md` では通常一覧と分けた「アーカイブ」表に記載する |
| 保持 | 現状のまま残す（歴史的経緯の参照価値がある場合）。索引の内容説明に「対応ソース削除済み」と注記する |

`archive/` 配下のドキュメントは `harness-update` の差分照合対象から除外される（`sources: []` のため）。

## 7. 既存資産との整合

| 状況 | 動作 |
|------|------|
| リポジトリルートに `CLAUDE.md` が既存 | 内容を `.claude/CLAUDE.md` と `references/` 配下へ取り込み、ルート側はユーザ確認のうえ「`.claude/CLAUDE.md` への参照のみ」に整理（無確認での削除・上書き禁止） |
| `docs/` 等の既存ドキュメントが存在 | 取り込み候補としてユーザに提示。取り込む場合も **元ファイルは変更しない**（コピー・要約のみ） |
| `.claude/references/` が既存 | `harness-init` は再構築確認、`harness-update` は本仕様との差分を検出して整合させる |

## 8. 記載品質の原則

- ソースコード・実動作から確認できた事実のみを記載する。推測で仕様を捏造しない
- 未確認・不明箇所は `TODO:` として明示し、判明時に `harness-update` で解消する
- 図解は mermaid 記法を使用する
- 各ドキュメントは「AI エージェントが読んで実装判断に使える」粒度を基準とする
