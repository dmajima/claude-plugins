---
name: test-review
description: テスト成果物を多観点レビューするスキル。設計文脈（test-plan.md/test-cases.yaml）は 3 エージェントで網羅性/実現性/ユーザー目線を評価し PASS/NEEDS REVISION 判定・approved 化。結果文脈は 2 エージェントで NG 原因/再現手順/severity 検証。「テストケースをレビューして」「テスト結果をレビューして」で起動。Use when reviewing artifacts/results. SKIP when designing (test-design) or running (test-run-*).
allowed-tools:
  - Read
  - Grep
  - Glob
  - Edit
  - AskUserQuestion
  - Bash(date *)
  - Agent(deep-test:coverage-reviewer)
  - Agent(deep-test:feasibility-reviewer)
  - Agent(deep-test:user-perspective-reviewer)
  - Agent(deep-test:defect-analyst)
---

# test-review スキル

テスト成果物の多観点レビューを担う単一責務のフェーズスキル。入力によって 2 文脈を切り替える。どちらの文脈でも指摘に重要度（Critical / High / Medium / Low）と信頼度（0〜100）を付与する。

| 文脈 | 入力 | 起動エージェント（並列） | 出力 |
|------|------|------------------------|------|
| 設計文脈 | test-plan.md + test-cases.yaml | coverage-reviewer / feasibility-reviewer / user-perspective-reviewer（3 並列） | 指摘統合 + PASS / NEEDS REVISION 判定。PASS 時は test-cases.yaml の `review_status` を approved 化 |
| 結果文脈 | 実行結果サマリ + test-results.yaml パス + エビデンス | defect-analyst / user-perspective-reviewer（2 並列） | NG 原因分類・再現手順完全性・severity 妥当性の検証レポート（report フェーズへの引き継ぎ事項含む） |

## 責務

| # | 責務 | 概要 |
|---|------|------|
| 1 | 文脈判定 | 入力（引数・渡されたパス）から設計文脈 / 結果文脈を判定 |
| 2 | 多観点レビューの実施 | 文脈別のエージェント構成（`${CLAUDE_PLUGIN_ROOT}/references/agents.md`）を 1 メッセージ内で並列起動。プロンプトには共通注入事項（同 4.3 章）を必ず含める |
| 3 | 指摘の統合 | 重複排除・矛盾の両論保持・重要度と信頼度によるランキング（`${CLAUDE_SKILL_DIR}/references/review-criteria.md`） |
| 4 | 判定（設計文脈のみ） | PASS / NEEDS REVISION を判定（基準: Critical / High 指摘が 1 件以上なら NEEDS REVISION） |
| 5 | 承認処理（設計文脈 PASS 時のみ） | test-cases.yaml のレビュー対象ケースの `review_status` を `approved` へ更新 |
| 6 | レビューレポート返却 | 文脈別フォーマットで統合結果・判定・引き継ぎ事項を返却 |

## 責務外（他スキルが担当）

| 責務外 | 担当 |
|-------|------|
| 指摘に基づく成果物（計画・ケース）の修正 | `test-design`（NEEDS REVISION 時の差し戻し先） |
| 設計レビューゲートの判定・修正ループ制御（上限 3 回） | オーケストレータ `test`（`execution-policy.md` 1.1 章） |
| テストの実行・実行結果の記録（test-results.yaml への書き込み） | `test-run-*` / オーケストレータ `test` |
| エビデンス完全性の最終監査（報告書生成前の validate） | `test-report`（evidence-auditor） |
| 報告書の生成 | `test-report` |

## トリガー条件

起動する:

- オーケストレータ `test` から Skill ツール経由で委譲（設計フェーズ後の設計レビュー・run 後の結果レビュー・承認済みケースゲートで要求された draft ケースの承認レビュー）
- 「テストケースをレビューして」「テスト計画をレビューして」「テスト結果をレビューして」と依頼された

起動しない:

- ソースコードのレビューを求められた（本スキルの対象はテスト成果物であり、コードレビューは対象外）
- ケースの修正・追加そのものを求められた（`test-design` の責務）
- 報告書の生成を求められた（`test-report` の責務）

## 前提

- `${CLAUDE_PLUGIN_ROOT}/references/common-references.md` 3.2（レビュー時）が参照する共通規範一式が存在する
- 対象エージェント定義（coverage-reviewer / feasibility-reviewer / user-perspective-reviewer / defect-analyst）がプラグインルート `agents/` に存在する

受け取る引数:

| 引数 | 内容 | 文脈 |
|------|------|------|
| `context=` | `design` / `results` の明示指定（省略時は入力パスから推定） | 共通 |
| `target-slug=`（別名 `target=`） | 対象 slug（パス解決用。委譲時にオーケストレータが渡す） | 共通 |
| `base=` | 基準ディレクトリ（委譲時に受領。省略時は `data-locations.md` 1 章で解決） | 共通 |
| `plan=` / `cases=` | test-plan.md / test-cases.yaml のパス（省略時は `{target-slug}/` 直下を採用） | 設計 |
| `scope=` | レビュー対象ケース ID（カンマ区切り。省略時は draft の全有効ケース） | 設計 |
| `results=` | test-results.yaml のパス（省略時は `{target-slug}/` 直下を採用） | 結果 |
| `run=`（別名 `run-id=`） | 対象 run_id（省略時は最新 run） | 結果 |
| 実行結果サマリ | レベル別集計・fail 概要（委譲時にオーケストレータが引数本文で渡す） | 結果 |
| `--non-interactive` | 非対話モード | 共通 |

## 実行モード判定

| 判定条件 | モード | 動作 |
|---------|-------|------|
| 引数に `--non-interactive` を含む（委譲時はオーケストレータが付与） | 非対話 | 文脈が判定できない場合はエラー中断（推測で進めない）。それ以外は確認なしで進行 |
| 上記以外 | 対話 | 文脈が曖昧な場合のみ AskUserQuestion で確認 |

## 実行フロー

詳細手順は `${CLAUDE_SKILL_DIR}/references/review-procedures.md`、判定・統合の基準は `${CLAUDE_SKILL_DIR}/references/review-criteria.md` に従う。

### 1. 文脈判定
入力を解釈し文脈（設計 / 結果）を判定。

### 2. レビュー対象確定
入力成果物を読み込みレビュー対象を確定（設計は対象ケースの抽出、結果は対象 run の fail・defect の抽出〔読み取りのみ〕）。

### 3. エージェント並列起動
文脈別のエージェント構成を 1 メッセージ内で並列起動（設計 3 並列 / 結果 2 並列。プロンプト組み立ては agents.md 4 章準拠）。

### 4. 指摘統合
各エージェントの結果を統合（重複排除・重要度 / 信頼度ランキング）。

### 5. 判定（設計文脈のみ）
PASS / NEEDS REVISION を判定。

### 6. 承認処理（設計文脈 PASS 時のみ）
test-cases.yaml のレビュー対象ケースの `review_status` を `approved` へ更新。

### 7. 返却
文脈別フォーマットでレビューレポートを返却。

## 検証

返却前に以下を確認する。未達成の項目は解消してから返却する。

- [ ] 文脈判定が入力と整合している（設計 / 結果を取り違えていない）
- [ ] 文脈に対応するエージェント構成を **1 メッセージ内で並列起動**した（agents.md 1 章の文脈別構成・3 章の並列原則）
- [ ] 全エージェントのプロンプトに共通注入事項ブロック（agents.md 4.3 章）と解決済みパスを含めた
- [ ] すべての指摘に重要度と信頼度（0〜100）が付与され、重複が統合されている（review-criteria.md）
- [ ] 判定が review-criteria.md のゲート基準と一致している（設計文脈）。エージェントの所見を総合判定として転記していない
- [ ] PASS 時の書き換えが「レビュー対象ケースの review_status + meta.updated_at」のみである（他フィールド・他ケースに変更がない）
- [ ] test-results.yaml へ書き込んでいない（結果文脈でも読み取りのみ）
- [ ] エージェントの未確認事項を「問題なし」と書き換えていない（レポートに未確認として転記した）

## 引き渡し（オーケストレータへの返却内容）

文脈別に以下のレポートを最終応答に含めて返却する（詳細な組み立ては review-procedures.md 6 章）。

設計文脈:

```markdown
## テスト設計レビュー結果（test-review / 設計文脈）

- 判定: PASS | NEEDS REVISION
- レビュー対象: <ケース数>件（scope の内訳）/ 起動エージェント: coverage / feasibility / user-perspective
- 指摘一覧（重要度降順 → 信頼度降順。各行: 対象ケース ID・指摘内容・根拠・重要度・信頼度・出所・推奨対応）
- 承認処理: 実施（approved 化したケース ID 一覧）| 未実施（NEEDS REVISION のため）
- 差し戻し事項（NEEDS REVISION 時: test-design への修正指示リスト）
- 未確認事項
```

結果文脈:

```markdown
## テスト結果レビュー結果（test-review / 結果文脈）

- 対象 run: <run_id> / fail <n> 件・blocked <n> 件・skipped <n> 件 / 起動エージェント: defect-analyst / user-perspective
- NG 分析（fail ごと: 原因分類・severity 妥当性〔妥当 / 補正案 + 根拠〕・再現手順完全性の検証結果）
- 指摘一覧（重要度降順 → 信頼度降順）
- report フェーズへの引き継ぎ事項（報告書への注記・エビデンス補完の要否・severity 補正案）
- 未確認事項
```

## 重要な制約

- 成果物の内容修正をしない（指摘・差し戻し事項の提示まで。修正は test-design の責務）。**唯一の例外**は設計文脈 PASS 時の承認処理で、書き換え範囲はレビュー対象ケースの `review_status` と `meta.updated_at` のみ（revision・steps 等の他フィールドに触れない）
- `test-results.yaml` へ書き込まない（結果文脈でも読み取り専用。severity 補正・エビデンス補完は引き継ぎ事項として提案するに留める）
- エージェントに総合判定（PASS / NEEDS REVISION）をさせない。判定は本スキルが統合結果から行う（agents.md 3 章）
- NEEDS REVISION 後の修正ループ制御（design への差し戻し実行・上限 3 回の管理）はオーケストレータの責務であり、本スキルは差し戻し事項の提示まで
- 指摘の重要度（レビュー指摘の対応必要度）と欠陥 severity（本番影響度。`severity-policy.md`）を混同しない
- 未確認事項を「問題なし」と書かない

## 参照

| 参照先 | 内容 |
|-------|------|
| `${CLAUDE_PLUGIN_ROOT}/references/common-references.md` | プラグイン共通規範の集約インデックス（本スキルの場面別参照は 3.2 章「レビュー時」） |
| `${CLAUDE_SKILL_DIR}/references/review-procedures.md` | 文脈判定・エージェント起動・統合・判定・承認処理の詳細手順 |
| `${CLAUDE_SKILL_DIR}/references/review-criteria.md` | 指摘重要度の定義・PASS / NEEDS REVISION 判定基準・指摘統合規則 |
