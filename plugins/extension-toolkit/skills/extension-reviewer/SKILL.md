---
name: extension-reviewer
description: Claude Code の拡張要素（スキル・プラグイン・マーケットプレイス・コマンド・エージェント・チーム・フック）を多角的に横断レビューするスキル。「foo スキルをレビュー」「bar プラグイン全体をチェック」「dmajima-claude-plugins マーケットプレイスをレビュー」「extension をレビュー」などの依頼で起動する。Use when the user wants a multi-perspective review of skills, plugins, marketplaces (marketplace.json + marketplace README), commands, agents, agent teams, or hooks before publishing or merging. SKIP when the user wants to create a new artifact (use the corresponding *-toolkit skill).
---

# Extension Reviewer

Claude Code の拡張要素（スキル・プラグイン・コマンド・エージェント・チーム・フック）を **多角的に横断レビュー** するスキル。実装エンジニア・アーキテクト・セキュリティエンジニア等の複数エージェントを並列起動し、専門観点別の指摘を統合する（ADR-006 並列起動最低 3 名・ADR-011 専門家分散準拠）。

## 責務

- 対象種別の判定とレビュー観点の選定
- 複数の専門エージェントの **並列起動**（最低 3 名）
- 観点別レビュー結果の統合・優先度付け（Critical / High / Medium / Low）
- 構造妥当性・内容妥当性・パスポータビリティ・AI 誤認回避・evals 充実度の確認
- 修正提案（任意で実施、合意のもとで適用）

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| 拡張要素の新規作成 | 各 `*-toolkit` |
| マーケットプレイス公開 | `marketplace-publisher` |
| 修正の実装 | レビュー結果に基づき各 `*-toolkit` を再起動 |

## トリガー条件

- 「`{name}` スキルをレビュー」「`{name}` プラグインをチェック」
- 「`{name}` マーケットプレイスをレビュー」「`marketplace.json` 妥当性チェック」
- 「`{path}` の構造妥当性を確認」
- 「公開前に多角レビュー」

このスキルを起動しないケース:

- 「新しいスキルを作って」（→ `skill-toolkit`）
- 「マーケットプレイスに公開」（→ `marketplace-publisher`、ただし内部で本スキルを呼ぶ場合あり）

## 前提

- レビュー対象が既存（パスを Read 可能）
- 対象種別（スキル / プラグイン / コマンド / エージェント / フック）が判定可能

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり | 非対話 | 自動レビュー、結果のみ提示、修正は実施しない |
| `--auto-fix` フラグあり | 自動修正 | 軽微な指摘（パスポータビリティ・プレースホルダ残存等）を自動修正 |
| 上記以外 | 対話 | 観点・修正方針をユーザに確認 |

## 実行フロー

### 1. 対象判定

| 対象 | 判定基準 |
|-----|--------|
| スキル | `SKILL.md` 含むディレクトリ |
| プラグイン | `.claude-plugin/plugin.json` 含むディレクトリ |
| マーケットプレイス | `.claude-plugin/marketplace.json` 含むリポジトリルート（プラグインと区別） |
| コマンド | `commands/{name}.md` 単体 |
| エージェント | `agents/{name}.md` 単体（frontmatter で識別） |
| チーム | チーム定義ファイル |
| フック | `hooks.json` 含むディレクトリ |

### 2. レビュー観点の選定

詳細は [references/review-perspectives.md](references/review-perspectives.md) を参照。

| 対象 | 主な観点（最低 3 名のエージェント担当） |
|-----|-------------------------------------|
| スキル | 実装品質 / アーキテクチャ / テスト・evals |
| プラグイン | 全スキル/コマンド/フック横断 + マーケットプレイス整合性 |
| マーケットプレイス | `marketplace.json` 妥当性 / マーケットプレイス README 整合性（ADR-019 同期）/ プラグイン一覧テーブルの正確性 |
| コマンド | 実装品質 / セキュリティ（実行コマンドの危険性） |
| エージェント | 観点網羅性 / 専門性の妥当性 |
| チーム | 観点網羅性 / メンバー相補性 / サイズ妥当性 |
| フック | セキュリティ（command 実行内容） / パスポータビリティ |

### 3. チームの選定 + 並列レビュー実施

レビューは **専門家を集めたチーム単位で起動** する（単独レビュアーへの集約を避け、観点ごとに分散）。

対象別の採用チームと専門家エージェント一覧は [references/team-selection.md](references/team-selection.md) を参照。

`TeamCreate` 機能が利用できない環境では、Agent ツールでメンバーを個別並列起動する **フォールバック** に切り替える。手順は [`../../references/agent-utilization.md`](../../references/agent-utilization.md) の「6.1 チーム機能が利用できない環境でのフォールバック」と [references/team-selection.md](references/team-selection.md) の「フォールバック起動」を参照。

機械チェック（[references/automated-checks.md](references/automated-checks.md)）を並行して実行する。

### 4. 共通自動チェック

エージェント起動と並行して、以下の機械的チェックを実施:

| チェック | 方法 |
|---------|------|
| SKILL.md 200 行以下 | `wc -l` |
| パスポータビリティ | Grep（[`../../references/path-portability.md`](../../references/path-portability.md)） |
| プレースホルダ残存（`{...}`） | Grep |
| frontmatter valid | YAML パース |
| JSON valid | JSON パース |
| `§` 記号の使用 | Grep |
| 必須セクション（責務 / 責務外 / トリガー条件 等）の存在 | パターン検索 |

詳細は [references/automated-checks.md](references/automated-checks.md) を参照。

### 5. 結果統合

各エージェントの結果と自動チェック結果を統合し、優先度別に整理:

```markdown
## レビュー結果統合

### Critical（即時修正必須）
- {問題}（{担当エージェント}, {ファイル:行}）

### High（修正推奨）
- {問題}（{担当エージェント}, {ファイル:行}）

### Medium（検討推奨）
- {問題}

### Low / Suggestion
- {改善提案}

### 総合判定
{APPROVE / CONDITIONAL_APPROVE / REJECT} — {理由 1 行}
```

### 6. 修正提案 / 自動修正

| モード | 動作 |
|-------|------|
| 通常 | 結果を提示、修正は別スキル（`*-toolkit`）で実施するよう案内 |
| `--auto-fix` | 軽微な指摘（パスポータビリティ・プレースホルダ・フォーマット）を自動修正 |

自動修正の対象外:

- 構造的な問題（責務分離違反等）
- 内容的な問題（description の不適切等）
- セキュリティ指摘（必ずユーザ確認）

### 7. 引き渡し

| 結果 | 接続先 |
|-----|-------|
| Critical/High なし | `marketplace-publisher` への接続を提案 |
| Critical/High あり | 該当 `*-toolkit` への接続を提案（修正後再レビュー推奨） |

## 重要な制約

- **レビューはチーム単位で起動**（[`../../references/teams/`](../../references/teams/) のチーム定義に従う）
- **レビューは必ずフレッシュ Agent インスタンスで起動**（[`../../references/review-freshness.md`](../../references/review-freshness.md)、ADR-021 準拠）。修正実装と同一コンテキストでレビューを行わない。スポーンプロンプトに必須引き継ぎ事項（目的 / 役割 / ユーザー指摘 / 対象 / 観点 / フォーマット）を明記し、引き継ぎ禁止事項（過去レビュー結論等）を含めない
- 標準は最低 3 名（観点が 2 つに固定の場合は 2 名でも可）
- メンバーは並列起動（独立観点）
- 自動修正は軽微な指摘のみ
- セキュリティ指摘は必ずユーザ確認
- このスキル自身では構造変更を伴う修正は行わない
- ユーザに選択を求める場合は `AskUserQuestion`（[`../../references/user-interaction.md`](../../references/user-interaction.md)）
- 作業完了報告前に [`../../references/completion-checklist.md`](../../references/completion-checklist.md) に基づく自己検証を実施

## 参照

| 用途 | ファイル |
|-----|---------|
| 命名・配置規約 | [`../../references/conventions.md`](../../references/conventions.md) |
| AI 誤認回避 | [`../../references/ai-readability.md`](../../references/ai-readability.md) |
| ポータブルパス | [`../../references/path-portability.md`](../../references/path-portability.md) |
| evals 設計 | [`../../references/eval-guide.md`](../../references/eval-guide.md) |
| 検証ルール（SSOT） | [`../../references/validation-rules.md`](../../references/validation-rules.md)（全節） |
| アーキテクチャ決定 | [`../../references/architecture-decisions.md`](../../references/architecture-decisions.md) |
| レビューフレッシュ起動原則 | [`../../references/review-freshness.md`](../../references/review-freshness.md) |
| 自己完結性ポリシー | [`../../references/self-containment.md`](../../references/self-containment.md) |
| レビュー観点 | [`references/review-perspectives.md`](references/review-perspectives.md) |
| チーム選定 | [`references/team-selection.md`](references/team-selection.md) |
| 自動チェック | [`references/automated-checks.md`](references/automated-checks.md) |
| 動作例 | [`evals/`](evals/) |
