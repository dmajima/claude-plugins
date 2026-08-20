---
name: harness-init
description: 対象プロジェクトを解析して .claude ハーネス（CLAUDE.md + references/ 配下の仕様・設計・検証環境ドキュメント体系）を初期構築するスキル。「プロジェクトの Claude 環境を整備して」「.claude ハーネスを初期化して」「.claude ハーネスを構築して」等の依頼で起動する。Use when initializing the .claude harness for a project. SKIP when the harness already exists and only needs syncing (use harness-update).
---

# Harness Init

対象プロジェクトを解析し、AI エージェントの足場となる `.claude` ハーネス（`CLAUDE.md` + `references/` 配下のドキュメント体系）を初期構築するスキル。

## 責務

- 対象プロジェクトの解析（技術スタック・機能・画面・アーキテクチャ・検証コマンド）
- `.claude/CLAUDE.md` + `.claude/references/` 一式の生成（[構成仕様](../../references/structure-spec.md) 準拠）
- 既存ドキュメント資産（ルート `CLAUDE.md`・`docs/` 等）の取り込み
- `.sync-state.json` の初期化（[同期仕様](../../references/sync-spec.md) 準拠）

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| 構築済みハーネスへのコード変更の差分反映 | `harness-update` |
| 対象プロジェクトのコード実装・修正 | （本プラグイン対象外） |

## トリガー条件

- 「プロジェクトの Claude 環境を整備して」
- 「.claude ハーネスを初期化して」「ハーネスを構築して」
- 「このプロジェクトに仕様・設計ドキュメント体系を作って」
- `/project-harness:init` コマンド経由

このスキルを起動しないケース:

- ハーネス構築済みプロジェクトでの変更反映（→ `harness-update`）

## 前提

呼び出し前に以下が確認可能であること:

1. 対象プロジェクトのルート（カレントディレクトリ、または引数で指定されたパス）
2. 対象が git リポジトリであること（`.sync-state.json` がコミット SHA を基準とするため）

git リポジトリでない場合は、`git init` の実施をユーザに提案してから進める。

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり | 非対話 | 確認なしで進行（既存資産は取り込み・生成範囲は主要機能を自動選定）。ただしユーザ判断が必須の前提 NG（git リポジトリでない / 既存ハーネスあり）は **自動処置せず中断** し、理由と対話モードでの再実行を案内する |
| 上記以外 | 対話 | 取り込み方針・生成範囲を `AskUserQuestion` で確認 |

## 実行フロー

### 1. 前提確認

- 入力: 対象プロジェクトルート
- 出力: 実行可否判定

git リポジトリ確認と既存ハーネス検査を行う。`.claude/references/.sync-state.json` が既存の場合は `harness-update` への切替を提案する（再構築の明示指示がある場合のみ続行）。詳細は [references/procedures.md](references/procedures.md) の「Phase 1」を参照。

### 2. 既存資産調査

- 入力: 対象プロジェクトルート
- 出力: 取り込み方針

ルート `CLAUDE.md`・`README`・`docs/` 等の既存ドキュメントを検出し、取り込み方針を確認する。**既存ファイルは変更しない**（取り込みはコピー・要約のみ。ルート `CLAUDE.md` の整理はユーザ承認時のみ）。

### 3. プロジェクト解析（サブエージェント並列）

- 入力: 対象プロジェクトルート + 既存資産
- 出力: 解析結果（技術スタック / 機能・画面一覧 / アーキテクチャ / 検証コマンド）

[references/agents.md](references/agents.md) の構成でサブエージェントを並列起動し、結果をメインで統合する。解析で判明した機能・画面一覧を提示し、初期ドキュメントの生成範囲をユーザが選択する（非対話時は主要機能を自動選定）。

### 4. ハーネス生成

- 入力: 解析結果 + 生成範囲
- 出力: `.claude/CLAUDE.md` + `references/` 一式
- 参照: [構成仕様](../../references/structure-spec.md) / [テンプレート](../../references/template/)

テンプレートのプレースホルダを解析結果で置換して生成する。ソースから確認できた事実のみ記載し、未確認箇所は `TODO:` として明示する（推測での捏造禁止）。

### 5. 同期状態の初期化

`.sync-state.json` を HEAD の SHA で初期化する（[同期仕様](../../references/sync-spec.md) 節 1）。

### 6. 検証

- [ ] 生成した全フォルダに `CLAUDE.md` 索引があり、ファイル実体と一致している
- [ ] 全ドキュメントに frontmatter（`title` / `sources` / `updated`）がある
- [ ] `.claude/CLAUDE.md` が 100 行以内
- [ ] 未置換プレースホルダ `{...}` が残っていない
- [ ] `.sync-state.json` が valid JSON で HEAD を指している

### 7. 引き渡し

生成ファイル一覧・解析サマリ・`TODO:` 残数を報告し、以後の運用（`/project-harness:update` による同期・SessionStart フックの鮮度通知）を案内する。

## 重要な制約

- 対象プロジェクトの既存ファイル（ソースコード・既存ドキュメント）を **無確認で変更・削除しない**
- 仕様・設計の記載はソース・実動作の根拠に基づく。確認できない内容は `TODO:` 明示（捏造禁止）
- `.claude/CLAUDE.md` は 100 行以内に保つ（詳細は `references/` へ委譲）
- 生成前にハーネス既存検査を必ず行う（既存構成の無確認上書き禁止）
- ユーザに選択を求める場合は `AskUserQuestion` を使用する

## 参照

| 用途 | ファイル |
|-----|---------|
| ハーネス構成仕様（SSOT） | [`../../references/structure-spec.md`](../../references/structure-spec.md) |
| 同期仕様（SSOT） | [`../../references/sync-spec.md`](../../references/sync-spec.md) |
| ドキュメント雛形 | [`../../references/template/`](../../references/template/) |
| 詳細手順 | [`references/procedures.md`](references/procedures.md) |
| エージェント運用定義 | [`references/agents.md`](references/agents.md) |
| 動作例 | [`evals/`](evals/) |
