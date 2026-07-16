# 設計ワークフロー詳細（4 フェーズ）

`orchestrator-design` の各フェーズの手順・成果物・品質ゲート。
成果物配置・品質ゲート形式・遡行規定の共通事項は `orchestrator-coding` と同一の運用とする（本ファイルでは設計 WF 固有の差分のみ規定）。

## 0. 共通規定

### 0.1 成果物の配置

```
.claude/.local/work/{yyyyMMdd_nn_summary}/
├── implementation-plan.md      # Phase 1 成果物
├── impact-analysis.md          # Phase 2 成果物
├── implementation-design.md    # Phase 3 成果物
├── design-report.md            # Phase 4 成果物（最終）
├── inputs/                     # ユーザ提供資料（読み取り専用）
└── workspace/                  # 中間生成物・一時ファイル
```

テンプレートは `../../../references/template/`（SSOT）を使用する。**コードの変更は行わない**（設計のみ）。

### 0.2 品質ゲート判定

各フェーズの成果物末尾に以下を必ず出力する:

```markdown
## 品質ゲート判定

- 判定: PASS / FAIL
- 理由: （判定根拠を 1〜3 行）
- SKIPPED 項目: （実施できなかった検証があれば列挙、なければ「なし」）
```

### 0.3 遡行規定

| 状況 | 遡行先 |
|------|-------|
| Phase 2 で前提（依頼理解）の誤りが判明 | Phase 1 |
| Phase 3 で分析不足が判明 | Phase 2 |
| Phase 4 で成果物の欠落を検出 | 該当フェーズ |

同一フェーズへの遡行は最大 3 回。超過時はユーザに状況（試行内容・残る問題・選択肢）を報告して判断を仰ぐ。

## Phase 1: Intake（指示受領）

| 項目 | 内容 |
|------|------|
| 目的 | 設計依頼の正確な理解とゴールの明文化 |
| 入力 | ユーザの設計依頼（テキスト / 参照ファイル / URL） |
| 成果物 | `implementation-plan.md`（`../../../references/template/implementation-plan.md`） |

手順:

1. セッション作業領域を作成する
2. 設計のゴール（何を決めれば完了か: 構造 / 技術選定 / データフロー / 移行方針 等）を明文化する
3. 制約（既存資産の維持・期限・技術制約）を整理し、不明点は `AskUserQuestion` で確認する
4. ブランチ方針は「コード変更なし」のため確認不要（成果物は作業領域のみ）

品質ゲート観点: 設計ゴールが明文化されているか。

## Phase 2: Analyze（分析）

| 項目 | 内容 |
|------|------|
| 目的 | 言語・規約の確定と現状構造の把握 |
| 入力 | implementation-plan.md |
| 成果物 | `impact-analysis.md`（`../../../references/template/impact-analysis.md`） |

手順:

1. **言語・FW 検出**: [language-detection.md](../../../references/language-detection.md) に従い適用言語スキルを確定する
2. **規約解決**: [conventions-resolution.md](../../../references/conventions-resolution.md) に従い適用規約サマリを生成する（設計書の記法・命名提案に使用）
3. **現状構造の把握**: 既存コードのアーキテクチャ（層構造・モジュール境界・依存方向）と設計対象への影響範囲を調査する。調査量が多い場合は read-only 系サブエージェントに委譲する

品質ゲート観点: 言語検出・規約サマリ・現状構造が記録されているか。

## Phase 3: Design（設計）

| 項目 | 内容 |
|------|------|
| 目的 | 設計書の作成と多角的検証 |
| 入力 | impact-analysis.md |
| 成果物 | `implementation-design.md`（`../../../references/template/implementation-design.md`） |

手順:

1. [design-principles.md](../../../references/design-principles.md)（SSOT）の設計観点（節 1）・リスク分類（節 2）・データフロー原則（節 3）に従って設計する
2. 言語のコード構造・FW 構造規約は適用言語スキルの references（`conventions.md` / `frameworks/`）を参照する
3. 実現方式が複数ある場合は代替案を比較し（評価軸: 設計観点 + リスク + 工数）、推奨案を `AskUserQuestion` で確認する（非対話モードでは推奨案を採用し理由を記録）
4. **設計レビュー**: [design-principles.md](../../../references/design-principles.md) 節 2.3 の判定基準に該当する場合、`architect` エージェントのレビューを実施し指摘を反映する（[agents.md](agents.md)）

品質ゲート観点: 設計観点・リスク対応・データフローが設計書に含まれるか / 代替案の採否理由が記録されているか。

## Phase 4: Report（報告）

| 項目 | 内容 |
|------|------|
| 目的 | 設計成果の集約と実装への引き継ぎ準備 |
| 入力 | 全フェーズ成果物 |
| 成果物 | `design-report.md`（`../../../references/template/design-report.md`） |

手順:

1. 設計の要点・代替案の採否・リスク対応方針・実装への引き継ぎ事項を design-report.md に集約する
2. **機密情報チェック**: 全成果物を Grep で走査し（`password` / `token` / `secret` / `Bearer ` / `sk-` / `AKIA` / PEM ヘッダ等）、検出時は `***` にマスクする
3. ユーザへ設計の要約を報告する。実装に進む場合は `orchestrator-coding` に設計成果物のパスを引き継ぐ（実装はユーザの明示指示があるまで開始しない）

品質ゲート観点: 全フェーズの成果物が揃っているか / 機密チェックが完了したか。
