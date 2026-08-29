# harness-define

プログラム実態がない状態（要件定義・仕様作成フェーズ）で、ユーザとの対話・提供資料に基づき `.claude` ハーネスの骨格と要件定義書・仕様設計書を作成する spec-first スキル。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。

## 使い方

### トリガーフレーズ例

- 「要件定義から始めたい」「要件定義書を作って」
- 「実装前に仕様を作って」「コードのないプロジェクトにハーネスを作って」
- 「この資料から仕様設計書を起こして」
- 「新機能の仕様を先行作成して」（構築済みハーネスへの追加）
- `/project-harness:define`

### 入力 → 出力の流れ

1. 対象プロジェクト（git リポジトリ。未初期化なら `git init` の可否を確認される）で起動する
2. 提供資料（要件メモ・議事録・既存ドキュメント）があれば取り込み方針を確認される（原本は変更されない）
3. 対話で要件をヒアリングされる（目的 → 機能一覧 → 画面・フロー → ルール・用語 → 非機能・制約）
4. `requirements/` + `specs/` 等の仕様先行ドキュメント（`status: draft`）とハーネス骨格が生成される
5. 生成内容の合意確認で承認したドキュメントが `status: agreed` になる
6. コミットが 1 つもない場合、`.claude/` 配下の初回コミットで同期基準が確立される
7. 実装開始後は `/project-harness:update` の実装追随が `sources` 紐付けと `implemented` 昇格を提案する

### コードがあるプロジェクトとの使い分け

| コード実態 | ハーネス | 使うスキル |
|-----------|---------|-----------|
| なし・僅少 | なし / あり | **harness-define** |
| あり | なし | `harness-init`（コード解析で構築） |
| あり | あり（コード変更の反映） | `harness-update` |
| あり | あり（未実装機能の仕様先行作成） | **harness-define** |

## 動作例

入力:

```text
/project-harness:define
```

出力（対象プロジェクト側）:

```text
<target-repo>/.claude/
├── CLAUDE.md                  # プロジェクト概要（合意済みの技術スタック等）
└── references/
    ├── CLAUDE.md              # ドキュメント索引・整理ルール
    ├── .sync-state.json       # 同期状態（初回コミット後に初期化）
    ├── requirements/          # 要件定義書（背景・スコープ・機能要求・非機能要求）
    ├── specs/                 # 仕様設計書（status: draft / agreed・sources: []）
    ├── flows/                 # 画面遷移・導線（同上）
    ├── architecture/          # 決定済みの構成方針（あれば）
    ├── decisions/             # 決定済みの技術判断（あれば）
    └── glossary.md            # ヒアリングで得たドメイン用語
```

生成される仕様ドキュメントの frontmatter 例:

```yaml
---
title: ログイン画面仕様
sources: []
related:
  - requirements/requirements.md
status: agreed
updated: 2026-08-29
---
```

## カスタマイズ・拡張

| 変更したいこと | 変更箇所 |
|--------------|---------|
| ハーネスのフォルダ構成・`status` ライフサイクル・骨格生成順序 | プラグイン共有 `references/structure-spec.md`（SSOT） |
| 記載の原則（合意根拠の扱い）・秘匿情報・検証項目 | プラグイン共有 `references/authoring-spec.md`（SSOT） |
| 実装追随（実装開始後の紐付け）の仕組み | プラグイン共有 `references/sync-spec.md`（SSOT） |
| 生成ドキュメントの雛形（要件定義書含む） | プラグイン共有 `references/templates/` 配下 |
| 資料調査・生成エージェントの観点 | `references/agents.md` |
| 実行手順の詳細 | `references/procedures.md` |

## ファイル構成

```text
skills/harness-define/
├── SKILL.md                   # スキル定義（Claude が実行時に読み込む）
├── README.md                  # 本ファイル（人間向け）
├── references/
│   ├── procedures.md          # Phase 1〜7 の詳細手順
│   └── agents.md              # 資料調査・生成エージェントの運用定義
└── evals/
    ├── README.md
    └── case-*.md              # 動作分岐の期待挙動
```
