---
name: orchestrator-design
description: 対象リポジトリの設計業務（実装なし）を 4 フェーズで統括する多言語オーケストレーター。言語検出で言語スキル 8 種の構造知識を参照し、設計原則 SSOT に基づく設計書を作成する。「設計して」「設計書を作って」「実装方針を検討して」等で起動する。Use when the user requests design documents without coding. SKIP if implementation is requested (orchestrator-coding) or single-language structure only (coding-*).
---

# Orchestrator Design（設計ワークフロー統括）

実装を伴わない設計業務（設計書作成・実装方針の検討・技術選定の整理）を 4 フェーズで統括する。設計観点・リスクヘッジ・データフローは SSOT（[design-principles.md](../../references/design-principles.md)）に、言語のコード構造は言語スキル（`coding-{lang}`）に委ねる。

## 責務

- 4 フェーズ（Intake → Analyze → Design → Report）の進行制御
- 言語・フレームワークの自動検出と言語スキルの選択
- 設計原則 SSOT と言語スキルの知識を統合した設計書の作成統括
- `architect` エージェントによる設計レビューの起動と結果統合

## 責務外（他スキルが担当）

| 業務 | 担当 |
|-----|------|
| 実装を伴う依頼（設計 + コーディング） | `orchestrator-coding`（Design フェーズを内包） |
| 言語・FW 固有のコード構造・規約 | 言語スキル `coding-{lang}`（[skill-index.md](../../references/skill-index.md) 参照） |
| 設計観点・リスクヘッジ・データフローの原則 | SSOT [design-principles.md](../../references/design-principles.md) |
| Claude Code 拡張要素の作成 | `extension-toolkit`（導入済み環境のみ・任意） |

## トリガー条件

- 「この機能の設計をして」「設計書を作って」
- 「実装方針を検討して」「どう作るべきか整理して」
- 「技術選定の比較をして」（コード変更を伴わない）

起動しないケース:

- 実装まで求められている（→ `orchestrator-coding`。設計は Phase 3 として実施される）
- 既存コードのレビューのみ（→ レビュー系スキル / エージェント）

## 前提

呼び出し前に以下が決まっていること:

1. 設計対象（機能・変更・課題の説明）
2. 対象リポジトリ（カレントディレクトリ基準）

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり | 非対話 | 確認をスキップしデフォルト値で進行。品質ゲート FAIL 時のみ中断して報告 |
| 上記以外 | 標準 | 不明点は `AskUserQuestion` で確認 |

## 実行フロー

各フェーズの詳細は [references/workflow.md](references/workflow.md) を参照。
成果物はセッション作業領域 `.claude/.local/work/{yyyyMMdd_nn_summary}/` に配置し、テンプレートは `../../references/template/` を使用する。

### Phase 1: Intake（指示受領）

- 入力: ユーザの設計依頼 / 出力: `implementation-plan.md`
- 設計のゴール（何を決めれば完了か）を明文化する

### Phase 2: Analyze（分析）

- 入力: implementation-plan.md / 出力: `impact-analysis.md`
- 言語検出と言語スキル選択: [language-detection.md](../../references/language-detection.md) + [skill-index.md](../../references/skill-index.md)
- 規約解決: [conventions-resolution.md](../../references/conventions-resolution.md)
- 現状構造の把握（既存コードのアーキテクチャ・依存関係）

### Phase 3: Design（設計）

- 入力: impact-analysis.md / 出力: `implementation-design.md`
- 設計観点・リスク評価・データフロー: [design-principles.md](../../references/design-principles.md)（SSOT）
- 言語のコード構造・FW 構造規約: 適用言語スキルの references を参照
- 複数案が拮抗する場合は代替案比較を設計書に含め、推奨案を `AskUserQuestion` で確認
- 大規模・高リスク（design-principles.md 節 2.3）は `architect` エージェントのレビューを実施（[references/agents.md](references/agents.md)）

### Phase 4: Report（報告）

- 入力: 全フェーズ成果物 / 出力: `design-report.md`（`../../references/template/design-report.md`）
- 機密情報チェックを実施し、設計の要点・代替案の採否・実装への引き継ぎ事項を報告する

### 品質ゲートと遡行

- 各フェーズの成果物末尾に「品質ゲート判定」（PASS / FAIL + 理由）を必ず出力する
- FAIL 時は該当フェーズ内で修正、解決不能なら前フェーズへ遡行する（同一フェーズ最大 3 回）

## 検証

- [ ] 検出した全言語の言語スキルを参照した（未対応言語は勝手に推測せずユーザに明示）
- [ ] 設計書に設計観点・リスク・データフロー（design-principles.md 準拠）が含まれている
- [ ] 代替案の採否理由が記録されている（複数案があった場合）
- [ ] 成果物に機密情報が含まれていない

## 引き渡し

- design-report.md の要約と、成果物一式が置かれた **セッション作業領域の絶対パス** をユーザに提示する
- 実装に進む場合は `orchestrator-coding` へ設計成果物のパスを引き継ぐ（実装はユーザの明示指示があるまで開始しない）

## 重要な制約

- **コードの変更を行わない**（設計のみ。実装が必要なら orchestrator-coding へ引き継ぐ）
- 言語・FW 固有の構造判断は必ず言語スキルの references に基づく
- 未対応言語では言語スキル不在をユーザに明示する
- ユーザに選択を求める場合は `AskUserQuestion` を使用する

## 参照

| 用途 | ファイル |
|-----|---------|
| フェーズ詳細・品質ゲート | [references/workflow.md](references/workflow.md) |
| エージェント運用定義 | [references/agents.md](references/agents.md) |
| 設計原則（SSOT） | [design-principles.md](../../references/design-principles.md) |
| 言語・FW 検出手順（SSOT） | [language-detection.md](../../references/language-detection.md) |
| 言語スキル対応表（SSOT） | [skill-index.md](../../references/skill-index.md) |
| 規約優先順位の解決（SSOT） | [conventions-resolution.md](../../references/conventions-resolution.md) |
| 成果物テンプレート（SSOT） | `../../references/template/` |
| 動作例 | [evals/](evals/) |
