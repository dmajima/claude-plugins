---
name: orchestrator-coding
description: リポジトリの実装業務を 6 フェーズで統括する多言語オーケストレーター。言語検出で言語スキル 8 種へ委譲し、プロジェクト独自規約を優先する。「実装して」「機能追加して」「バグを直して」等で起動する。Use when the user requests code implementation or bug fixes. SKIP if design-only (orchestrator-design), 1-3 file single-language tasks (coding-*), or extension work (extension-toolkit).
---

# Orchestrator Coding（実装ワークフロー統括）

言語・フレームワークを自動検出し、プロジェクト規約準拠の実装を 6 フェーズで統括する。制御（フェーズ進行・遡行判断）のみを担い、言語固有知識は言語スキル（`coding-{lang}`）へ、品質評価は品質ゲートとレビューエージェントへ委ねる。

## 責務

- 6 フェーズ（Intake → Analyze → Design → Implement → Self-Review → Report）の進行制御と、品質ゲート判定に基づく遡行制御
- 言語・フレームワークの自動検出と言語スキルの選択
- コーディング規約の優先順位解決（プロジェクト独自規約 > 言語スキルのデファクト規約）
- レビューエージェントの起動と結果統合

## 責務外（他スキルが担当）

| 業務 | 担当 |
|-----|------|
| 設計のみの依頼（実装を伴わない） | `orchestrator-design` |
| 言語・FW 固有の規約・コード構造・実装知識 | 言語スキル `coding-{lang}`（[skill-index.md](../../references/skill-index.md) 参照） |
| 設計観点・リスクヘッジ・データフローの原則 | SSOT [design-principles.md](../../references/design-principles.md) |
| Claude Code 拡張要素（スキル/プラグイン等）の作成 | `extension-toolkit`（導入済み環境のみ・任意） |
| PR / 課題へのコメント投稿 | `connector` プラグイン（導入済み環境のみ・任意） |

## トリガー条件

起動する: 「この機能を実装して」「○○を追加して」「このバグを修正して」「リファクタリングして」「コーディングして」「この仕様どおりに作って」

起動しないケース:

- 1〜2 行の明白な修正（→ 直接編集で十分）
- 設計書の作成だけ・特定言語の知識だけ・スキル/プラグイン/コマンドの作成（→ 上表「責務外」の担当スキルへ。拡張要素は未導入環境では対象外の依頼として扱う）

## 前提

呼び出し前に以下が決まっていること:

1. タスク内容（実装したい機能・修正したい不具合の説明）
2. 対象リポジトリ（カレントディレクトリ基準）

曖昧な場合は Phase 1（Intake）で確認する。

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり | 非対話 | 確認をスキップしデフォルト値で進行。品質ゲート FAIL 時のみ中断して報告 |
| タスク規模が小（1〜3 ファイル・方針が自明） | クイック | Phase 2+3 を統合し、成果物を簡略化（[references/workflow.md](references/workflow.md) の簡略化規定） |
| 上記以外 | 標準 | 全 6 フェーズを実施。不明点は `AskUserQuestion` で確認 |

## 実行フロー

各フェーズの詳細手順・入力・参照 SSOT・品質ゲート観点は [references/workflow.md](references/workflow.md) を参照（フロー開始時に必読）。下表は制御用の要約。成果物はセッション作業領域 `.claude/.local/work/{yyyyMMdd_nn_summary}/`（リポジトリ配下優先、なければ `~/.claude/.local/work/`）に配置し、テンプレートは `../../references/template/` を使用する。

| Phase | 目的 | 成果物 | 主要ゲート・分岐 |
|-------|------|-------|----------------|
| 1 Intake（指示受領） | タスク理解と作業分解 | `implementation-plan.md` | 不明点は `AskUserQuestion`（非対話は最も保守的な解釈を採用し記録） |
| 2 Analyze（分析） | 言語・FW・規約の確定と影響範囲把握 | `impact-analysis.md`（**言語検出結果・適用スキル・適用規約サマリ** を必須セクション） | 言語検出・規約解決を実施（SSOT は末尾「参照」表） |
| 3 Design（設計） | 実装方針の確定とリスク評価 | `implementation-design.md` | design-principles.md 節 2.3 の大規模・高リスク判定に該当する変更は `architect` の設計レビューを実施 |
| 4 Implement（実装） | 規約準拠の実装とローカル検証 | コード変更 + `file-list.md` | 適用規約サマリに準拠。ビルド/Lint 検証（実行不能は SKIPPED） |
| 5 Self-Review（自己レビュー） | 独立視点の品質検証 | `self-review-result.md` | `impl-reviewer` + `test-engineer` を並列起動。Critical/High は Phase 4 へ遡行（設計起因は Phase 3） |
| 6 Report（報告） | 成果集約と最終検証 | `implementation-report.md` | 全成果物の機密情報チェック |

### 品質ゲートと遡行

- 各フェーズの成果物末尾に「品質ゲート判定」（PASS / FAIL + 理由）を必ず出力する
- FAIL 時は該当フェーズ内で修正、解決不能なら前フェーズへ遡行する（詳細: [references/workflow.md](references/workflow.md)）
- 同一フェーズへの遡行が 3 回を超えたらユーザに状況を報告し判断を仰ぐ

## 検証

- [ ] 検出した全言語の言語スキルを参照した（未対応言語は勝手に推測せずユーザに明示）
- [ ] プロジェクト独自規約が存在する場合、言語スキルのデファクト規約より優先して適用した
- [ ] 変更コードがビルド / Lint を通過した（ツールチェーンが利用可能な場合）
- [ ] Self-Review の Critical / High 指摘が 0 件になった
- [ ] 成果物に機密情報が含まれていない

## 引き渡し

- implementation-report.md の要約と、成果物一式が置かれた **セッション作業領域の絶対パス** をユーザに提示する（コミット・PR 作成は「重要な制約」の規定に従い実行しない）

## 重要な制約

- オーケストレーターは品質を評価しない（品質ゲート判定とレビュー結果を読んで分岐のみ行う）
- 言語・FW 固有の規約判断は必ず言語スキルの references と規約解決結果に基づく
- 未対応言語では言語スキル不在をユーザに明示する（[language-detection.md](../../references/language-detection.md)）
- `inputs/` 配下のユーザ提供資料は読み取り専用として扱う
- コミット・push・PR 作成はユーザの明示指示があるまで実行しない
- ユーザに選択を求める場合は `AskUserQuestion` を使用する

## 参照

| 用途 | ファイル |
|-----|---------|
| フェーズ詳細・品質ゲート・遡行規定 | [references/workflow.md](references/workflow.md) |
| エージェント運用定義 | [references/agents.md](references/agents.md) |
| 言語・FW 検出手順（SSOT） | [language-detection.md](../../references/language-detection.md) |
| 言語スキル対応表（SSOT） | [skill-index.md](../../references/skill-index.md) |
| 規約優先順位の解決（SSOT） | [conventions-resolution.md](../../references/conventions-resolution.md) |
| 設計原則（SSOT） | [design-principles.md](../../references/design-principles.md) |
| 成果物テンプレート（SSOT） | `../../references/template/` |
| 動作例 | [evals/](evals/) |
