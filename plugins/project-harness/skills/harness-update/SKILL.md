---
name: harness-update
description: 構築済みの .claude ハーネスに対し、最終同期コミット以降のコード変更を検出して影響ドキュメントと索引 CLAUDE.md を更新するスキル。「ハーネスを更新して」「変更をドキュメントに反映して」「開発内容を .claude に同期して」等の依頼や SessionStart フックの鮮度通知を受けて起動する。Use when code changes need to be synced into the existing .claude harness. SKIP when the harness does not exist yet (use harness-init).
---

# Harness Update

構築済みの `.claude` ハーネスへ、開発・修正で生じたコード変更を差分反映するスキル。
`.sync-state.json` の最終同期コミットと HEAD の差分から影響ドキュメントを特定し、記載内容・索引・同期状態を最新化する。

## 責務

- 最終同期コミット以降の変更ファイル検出と影響ドキュメントの特定（[同期仕様](../../references/sync-spec.md) 準拠）
- 影響ドキュメントの記載更新・新規ドキュメント作成・整理候補の提案
- 各フォルダ `CLAUDE.md` 索引とファイル実体の同期
- `.sync-state.json` の更新

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| ハーネスの初期構築 | `harness-init` |
| 対象プロジェクトのコード実装・修正 | （本プラグイン対象外） |

## トリガー条件

- 「ハーネスを更新して」「変更をドキュメントに反映して」
- 「開発内容を .claude に同期して」
- SessionStart フックの鮮度通知（乖離コミット数が閾値超過）を受けた実行
- `/project-harness:update` コマンド経由

このスキルを起動しないケース:

- ハーネス未構築プロジェクト（→ `harness-init`）

## 前提

呼び出し前に以下が存在すること:

1. `.claude/references/.sync-state.json`（無ければ `harness-init` への切替を提案）
2. git リポジトリであること

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり | 非対話 | 確認なしで全影響ドキュメントを反映（削除・アーカイブは実施せず提案のみ報告） |
| 上記以外 | 対話 | 反映計画を提示し `AskUserQuestion` で確認 |

## 実行フロー

### 1. 前提確認・差分取得

- 入力: `.sync-state.json`
- 出力: 変更ファイル一覧（A/M/D/R）

`last_synced_commit..HEAD` の差分を取得する。乖離ゼロなら「同期済み」を報告して終了。SHA 到達不能（rebase 等）時の扱いは [references/procedures.md](references/procedures.md) の「Phase 1」を参照。

### 2. 影響分析

- 入力: 変更ファイル一覧 + `references/` 全ドキュメントの frontmatter `sources`
- 出力: 反映計画（更新対象 / 新規候補 / 整理候補）

[同期仕様](../../references/sync-spec.md) 節 2 の分類で影響を仕分ける。

### 3. 反映計画の確認

反映計画（更新 N 件 / 新規 M 件 / 整理候補 K 件）を提示する。対話モードでは `AskUserQuestion` で対象を確定する。

### 4. 反映実行

- 入力: 確定した反映計画
- 出力: 更新済みドキュメント

変更内容（diff・必要に応じてソース本体）を確認し、記載と実装の乖離を解消する。更新量が多い場合は [references/agents.md](references/agents.md) の構成でサブエージェントに委譲する。**記載はソースの根拠に基づき、確認できない内容は `TODO:` 明示**（捏造禁止）。

### 5. 索引・同期状態の更新

- 影響フォルダの `CLAUDE.md` 索引をファイル実体と一致させる
- 更新ドキュメントの frontmatter `updated` を更新する
- `.sync-state.json` の `last_synced_commit` / `last_synced_at` を HEAD で更新する

### 6. 検証

- [ ] 反映対象すべてが更新済み（計画と実績の一致）
- [ ] 索引 `CLAUDE.md` とファイル実体が一致している
- [ ] 未置換プレースホルダ・frontmatter 欠落がない
- [ ] `.sync-state.json` が HEAD を指している

### 7. 引き渡し

反映結果（更新 / 新規 / 整理提案・スキップ理由）・`TODO:` 残数・未コミット変更の有無を報告する。

## 重要な制約

- ドキュメントの削除・アーカイブは **ユーザ承認時のみ** 実施（非対話モードでは提案のみ）
- 対象プロジェクトのソースコードを変更しない（反映方向はコード → ドキュメントの一方向）
- 記載はソース・diff の根拠に基づく。確認できない内容は `TODO:` 明示（捏造禁止）
- `.claude/CLAUDE.md` の 100 行以内維持（超過しそうな場合は `references/` へ委譲）
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
