---
name: orchestrator-coding
description: リポジトリの実装業務を 6 フェーズで統括する多言語オーケストレーター。言語検出で言語スキル 8 種へ委譲し、プロジェクト独自規約を優先する。「実装して」「機能追加して」「バグを直して」等で起動する。Use when the user requests code implementation or bug fixes. SKIP when design-only (use orchestrator-design), 1-3 file single-language tasks (use coding-*), or extension work (use extension-toolkit).
---

# Orchestrator Coding（実装ワークフロー統括）

対象リポジトリの言語・フレームワークを自動検出し、プロジェクト規約に準拠した実装を 6 フェーズで統括するオーケストレータースキル。制御（フェーズ進行・遡行判断）のみを担い、言語固有の知識は言語スキル（`coding-{lang}`）へ、品質評価は品質ゲートとレビューエージェントへ委ねる。

## 責務

- 6 フェーズ（Intake → Analyze → Design → Implement → Self-Review → Report）の進行制御
- 言語・フレームワークの自動検出と言語スキルの選択
- コーディング規約の優先順位解決の統括（プロジェクト独自規約 > 言語スキルのデファクト規約）
- フェーズ成果物の品質ゲート判定に基づく遡行制御
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

- 「この機能を実装して」「○○を追加して」
- 「このバグを修正して」「リファクタリングして」
- 「コーディングして」「この仕様どおりに作って」

このスキルを起動しないケース:

- 設計書の作成だけを依頼された（→ `orchestrator-design`）
- 1〜2 行の明白な修正（→ 直接編集で十分）
- 特定言語の知識だけを聞かれた（→ 該当する言語スキル `coding-{lang}`）
- スキル・プラグイン・コマンドの作成（→ `extension-toolkit`。未導入環境では対象外の依頼として扱う）

## 前提

呼び出し前に以下が決まっていること:

1. タスク内容（実装したい機能・修正したい不具合の説明）
2. 対象リポジトリ（カレントディレクトリ基準）

タスク内容が曖昧な場合は Phase 1（Intake）で確認する。

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり | 非対話 | 確認をスキップしデフォルト値で進行。品質ゲート FAIL 時のみ中断して報告 |
| タスク規模が小（1〜3 ファイル・方針が自明） | クイック | Phase 2+3 を統合し、成果物を簡略化（[references/workflow.md](references/workflow.md) の簡略化規定） |
| 上記以外 | 標準 | 全 6 フェーズを実施。不明点は `AskUserQuestion` で確認 |

## 実行フロー

各フェーズの詳細手順・成果物・品質ゲートは [references/workflow.md](references/workflow.md) を参照。
成果物はセッション作業領域 `.claude/.local/work/{yyyyMMdd_nn_summary}/`（リポジトリ配下優先、なければ `~/.claude/.local/work/`）に配置し、テンプレートは `../../references/template/` を使用する。

### Phase 1: Intake（指示受領）

- 入力: ユーザのタスク説明 / 出力: `implementation-plan.md`
- 不明点があれば `AskUserQuestion` で確認（非対話モードでは最も保守的な解釈を採用し記録）

### Phase 2: Analyze（分析）

- 入力: implementation-plan.md / 出力: `impact-analysis.md`（**言語検出結果・適用スキル・適用規約サマリ** を必須セクションとして含む）
- 言語検出と言語スキル選択: [language-detection.md](../../references/language-detection.md) + [skill-index.md](../../references/skill-index.md)
- 規約の優先順位解決: [conventions-resolution.md](../../references/conventions-resolution.md)（選択した言語スキルの `references/conventions.md` をデフォルト規約として使用）

### Phase 3: Design（設計）

- 入力: impact-analysis.md / 出力: `implementation-design.md`
- 設計観点・リスク評価・データフロー: [design-principles.md](../../references/design-principles.md)（SSOT）に従う
- 言語のコード構造・FW 構造規約: 適用言語スキルの references を参照する
- 大規模・高リスク変更（design-principles.md 2.3 の判定基準）は `architect` エージェントの設計レビューを実施

### Phase 4: Implement（実装）

- 入力: implementation-design.md + 適用規約サマリ / 出力: コード変更 + `file-list.md`
- 適用言語スキルの規約・実装ガイダンスに準拠して実装し、ツールチェーン（ビルド / Lint / フォーマット）で検証する
- エージェント委譲時は適用規約サマリ + 言語スキルの conventions.md 絶対パスをプロンプトに含める

### Phase 5: Self-Review（自己レビュー）

- 入力: file-list.md + 適用規約サマリ / 出力: `self-review-result.md`
- `impl-reviewer` + `test-engineer` エージェントを並列起動（[references/agents.md](references/agents.md)）
- Critical / High 指摘があれば Phase 4 へ遡行（同一フェーズへの遡行は最大 3 回）

### Phase 6: Report（報告）

- 入力: 全フェーズ成果物 / 出力: `implementation-report.md`
- 全成果物に対する機密情報チェック（接続文字列・トークン・鍵の混入検査）を実施

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

- implementation-report.md の要約と、成果物一式が置かれた **セッション作業領域の絶対パス** をユーザに提示する
- コミット・PR 作成はユーザの明示指示があるまで実行しない

## 重要な制約

- オーケストレーターは品質を評価しない（各フェーズの品質ゲート判定とレビューエージェントの結果を読んで分岐のみ行う）
- 言語・FW 固有の規約判断は必ず言語スキルの references と規約解決結果に基づく（本文への直書き禁止）
- 未対応言語で作業する場合、言語スキル不在をユーザに明示する（[language-detection.md](../../references/language-detection.md)）
- `inputs/` 配下のユーザ提供資料は読み取り専用として扱う
- コミット・push はユーザの明示指示があるまで実行しない
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
