# harness-init

対象プロジェクトを解析し、AI エージェントの足場となる `.claude` ハーネス（`CLAUDE.md` + `references/` 配下のドキュメント体系）を初期構築するスキル。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。

## 使い方

### トリガーフレーズ例

- 「プロジェクトの Claude 環境を整備して」
- 「.claude ハーネスを初期化して」
- 「このプロジェクトに仕様・設計ドキュメント体系を作って」
- `/project-harness:init`

### 入力 → 出力の流れ

1. 対象プロジェクト（git リポジトリ）で起動する
2. 既存資産（ルート CLAUDE.md・README・docs/）の取り込み方針を確認される
3. サブエージェントがプロジェクトを並列調査（技術スタック / 機能・画面 / アーキテクチャ / 規約・用語）
4. 検出された機能一覧から、初期ドキュメントの生成範囲を選択する
5. `environments/` に記載する検証コマンドの実行可否を確認される（対象リポジトリのコード実行を伴うため）
6. `.claude/CLAUDE.md` + `references/` 一式が生成され、検証スクリプトが実行され、`.sync-state.json` が初期化される
7. ルート `CLAUDE.md` へ `@.claude/CLAUDE.md` の import 行を追記して入口をつなぐ（承認時のみ）

## 動作例

入力:

```text
/project-harness:init
```

出力（対象プロジェクト側）:

```text
<target-repo>/.claude/
├── CLAUDE.md                  # プロジェクト概要・技術スタック
└── references/
    ├── CLAUDE.md              # ドキュメント索引・整理ルール
    ├── .sync-state.json       # 同期状態
    ├── specs/                 # 仕様設計書
    ├── system-designs/        # 詳細設計書
    ├── flows/                 # 画面位置・アクセス手順
    ├── environments/          # ビルド・テスト・検証コマンド
    ├── conventions/           # コーディング規約
    ├── architecture/          # システム構成・データモデル
    ├── decisions/             # ADR
    └── glossary.md            # ドメイン用語集
```

## カスタマイズ・拡張

| 変更したいこと | 変更箇所 |
|--------------|---------|
| ハーネスのフォルダ構成・frontmatter と sources 記法・モノレポ適用 | プラグイン共有 `references/structure-spec.md`（SSOT） |
| 記載の原則・秘匿情報の扱い・検証項目 | プラグイン共有 `references/authoring-spec.md`（SSOT） |
| 生成ドキュメントの雛形 | プラグイン共有 `references/templates/` 配下 |
| 調査エージェントの観点 | `references/agents.md` |
| 実行手順の詳細 | `references/procedures.md` |

## ファイル構成

```text
skills/harness-init/
├── SKILL.md                   # スキル定義（Claude が実行時に読み込む）
├── README.md                  # 本ファイル（人間向け）
├── references/
│   ├── procedures.md          # Phase 1〜7 の詳細手順
│   └── agents.md              # 調査・生成エージェントの運用定義
└── evals/
    ├── README.md
    └── case-*.md              # 動作分岐の期待挙動
```
