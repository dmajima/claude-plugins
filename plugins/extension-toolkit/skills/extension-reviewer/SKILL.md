---
name: extension-reviewer
description: Claude Code 拡張要素（スキル・プラグイン・マーケットプレイス・コマンド・エージェント・チーム・フック）を多角的に横断レビューするスキル。「foo スキルをレビュー」「bar プラグインを全体チェック」「マーケットプレイスをレビュー」等で起動する。Use when wanting a multi-perspective review before publishing/merging. SKIP when creating a new artifact (use skill/plugin/command/agent/hook/marketplace/mit-license-toolkit) or publishing (marketplace-publisher).
---

# Extension Reviewer

Claude Code の拡張要素（スキル・プラグイン・コマンド・エージェント・チーム・フック）を **多角的に横断レビュー** するスキル。実装エンジニア・アーキテクト・セキュリティエンジニア等の複数エージェントを並列起動し、専門観点別の指摘を統合する（ADR-006 並列起動最低 3 名・ADR-011 専門家分散準拠）。

## 責務

- 対象種別の判定とレビュー観点の選定
- 複数の専門エージェントの **並列起動**（最低 3 名）
- 観点別レビュー結果の統合・優先度付け（Critical / High / Medium / Low）
- 構造妥当性・内容妥当性・パスポータビリティ・AI 誤認回避・evals 充実度の確認
- **レビュー結果報告前の [`references/checklists/`](references/checklists/) 全項目走査（MANDATORY）**
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
**実行は必ず Bash 経由 + venv 内 Python + JSON ファイル出力**（`references/scripts/checks/run_checks.py`）。
venv はプラグイン直下 `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/` の事前ビルドスクリプトに委譲する（ADR-024）。
PowerShell から `python` を直接起動すると Claude Code の stdout 解釈と衝突して
文字化け（`â€` パターン）が発生するため禁止。

### 4. 共通自動チェック

エージェント起動と並行して、以下の機械的チェックを実施:

| チェック | 方法 |
|---------|------|
| SKILL.md 200 行以下 | `references/scripts/checks/run_checks.py` |
| パスポータビリティ | 同上（[`../../references/path-portability.md`](../../references/path-portability.md) 準拠） |
| プレースホルダ残存（`{...}`） | 同上 |
| frontmatter valid | 同上（PyYAML パース） |
| JSON valid | 同上 |
| `§` 記号の使用 | 同上 |
| 必須セクション（責務 / 責務外 / トリガー条件 等）の存在 | 同上 |
| description 文字数 / `argument-hint`（ADR-023） | 同上 |
| シークレット混入 | 同上（[`../marketplace-publisher/references/secret-scan.md`](../marketplace-publisher/references/secret-scan.md) と同等） |

実行は **必ず PowerShell 経由 + venv** で行う（shell-preference.md 準拠、Bash ツールは原則禁止）。
venv 関連はプラグイン直下スクリプト（ADR-024）に委譲。
各 `.ps1` 先頭で `[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)` を明示するため文字化けは発生しない。
詳細手順は [references/automated-checks.md](references/automated-checks.md) を参照。

```powershell
# 1. venv 構築（初回のみ・プラグイン共通）
pwsh -NoProfile -File "$env:CLAUDE_PLUGIN_ROOT/references/scripts/setup/setup_venv.ps1" `
  -WorkDir "$SessionDir/workspace" `
  -RequirementsPath "$env:CLAUDE_PLUGIN_ROOT/references/scripts/setup/requirements.txt"

# 2. チェック実行（出力は JSON ファイル）
& "$SessionDir/workspace/.venv/Scripts/python" `
  "$env:CLAUDE_SKILL_DIR/references/scripts/checks/run_checks.py" `
  --target "<対象パス>" --scope-root "<スコープルート>" `
  --output "$SessionDir/workspace/checks_result.json"

# 3. 完了後の venv 削除（プラグイン共通）
pwsh -NoProfile -File "$env:CLAUDE_PLUGIN_ROOT/references/scripts/setup/teardown_venv.ps1" `
  -WorkDir "$SessionDir/workspace"
```

### 5. 結果統合

各エージェントの結果と自動チェック結果を統合し、優先度別に整理（Critical / High / Medium / Low / Suggestion + 総合判定 APPROVE / CONDITIONAL_APPROVE / REJECT）。詳細フォーマットは [`references/review-perspectives.md`](references/review-perspectives.md) の「総合判定ルール」を参照。

### 6. チェックリスト走査（**最重要・MANDATORY**）

**ユーザへの最終報告を組み立てる前に必ず実施する。本ステップを省略してレビュー結果を報告してはならない。**

| 動作 | 内容 |
|-----|------|
| 適用ファイル選定 | [`references/checklists/README.md`](references/checklists/README.md) 節 2 のテーブルから対象種別に応じた適用ファイルを決定 |
| 全項目走査 | 適用ファイル（`common.md` + 対象種別別 + `process.md` + 該当時 `versioning.md` / `scripts-policy.md`）の全項目を走査 |
| 判定 | 各項目を OK / NG / NA（理由必須）の 3 値で判定 |
| 未確認項目の解消 | High 以上に未確認が残る場合、追加レビューまたは未確認理由の確定 |
| 通過記録の作成 | 適用ファイルごとに項目数 / OK / NG / 未確認の集計を組み立てる |

このステップ完了まで「総合判定」を確定してはならない。詳細は [`references/checklists/README.md`](references/checklists/README.md) を参照。

### 7. 修正提案 / 自動修正

| モード | 動作 |
|-------|------|
| 通常 | 結果を提示、修正は別スキル（`*-toolkit`）で実施するよう案内 |
| `--auto-fix` | 軽微な指摘（パスポータビリティ・プレースホルダ・フォーマット）を自動修正 |

自動修正の対象外: 構造的問題（責務分離違反）/ description 不適切 / セキュリティ指摘（必ずユーザ確認）。

### 8. 引き渡し

| 結果 | 接続先 |
|-----|-------|
| Critical/High なし | `marketplace-publisher` への接続を提案 |
| Critical/High あり | 該当 `*-toolkit` への接続を提案（修正後再レビュー推奨） |

報告には [`references/checklists/README.md`](references/checklists/README.md) 節 5 の「チェックリスト通過記録」テーブルを **必ず含める**。

## 重要な制約

- **【最重要・MANDATORY】レビュー結果報告の直前に必ず [`references/checklists/`](references/checklists/) の適用ファイル全項目を走査する**。未走査・部分走査での総合判定確定は禁止。High 以上の未確認項目がある場合、総合判定は最大 `CONDITIONAL_APPROVE` とし、未確認理由を報告に明記する
- **レビューはチーム単位で起動**（[`../../references/teams/`](../../references/teams/) のチーム定義に従う）
- **レビューは必ずフレッシュ Agent インスタンスで起動**（[`../../references/review-freshness.md`](../../references/review-freshness.md)、ADR-021 準拠）。修正実装と同一コンテキストでレビューを行わない。スポーンプロンプトに必須引き継ぎ事項（目的 / 役割 / ユーザー指摘 / 対象 / 観点 / フォーマット）を明記し、引き継ぎ禁止事項（過去レビュー結論等）を含めない
- 標準は最低 3 名（観点が 2 つに固定の場合は 2 名でも可）。メンバーは並列起動（独立観点）
- 自動修正は軽微な指摘のみ。セキュリティ指摘は必ずユーザ確認
- このスキル自身では構造変更を伴う修正は行わない
- ユーザに選択を求める場合は `AskUserQuestion`（[`../../references/user-interaction.md`](../../references/user-interaction.md)）
- 作業完了報告前に [`../../references/completion-checklist.md`](../../references/completion-checklist.md) に基づく自己検証を実施

## 参照

| 用途 | ファイル |
|-----|---------|
| **【最重要】レビュー全項目チェックリスト** | [`references/checklists/`](references/checklists/) |
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
