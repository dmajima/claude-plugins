# 参加エージェントの選定とプロンプト構成

`deep-test` プラグイン配下のスキルが参加させるエージェントの選定ルール・起動方式・プロンプト組み立て方・共通注入事項を定義する。

> **構造**: エージェントの直接起動は **worker スキル**（`test-analyze` / `test-design` / `test-review` / `test-report`）が担当する。
> オーケストレータ `test` はフェーズスキルの Skill 起動のみを行い、エージェントを直接起動しない。
> エージェントはレビュー・分析・監査のみを担当し、成果物（test-cases.yaml / test-results.yaml / 報告書）の修正・書き込みは行わない。

---

## 1. エージェント一覧と選定表

プラグインルート `agents/` に配置した共有エージェント定義を `subagent_type` で指定して呼び出す。

| ID | subagent_type | 役割 | 起動スキル（文脈） |
|----|--------------|------|------------------|
| src | `deep-test:source-analyst` | 解析材料（analysis.yaml / target-analysis.md）の網羅性・根拠妥当性の自己チェック | `test-analyze`（Phase 1.5） |
| arch | `deep-test:test-architect` | テスト戦略・レベル選定・計画の妥当性評価 | `test-design` |
| cov | `deep-test:coverage-reviewer` | 網羅性レビュー（要件対応・境界値・異常系・同値分割） | `test-review`（設計文脈） |
| feas | `deep-test:feasibility-reviewer` | 実行可能性・自動化適合性・環境依存リスクの評価 | `test-review`（設計文脈） |
| user | `deep-test:user-perspective-reviewer` | ユーザー目線・UAT 観点・業務シナリオ妥当性の評価 | `test-review`（設計・結果の両文脈） |
| defect | `deep-test:defect-analyst` | NG 分析・原因分類・再現手順の再構成・severity 妥当性の検証 | `test-review`（結果文脈） |
| evid | `deep-test:evidence-auditor` | エビデンス完全性・再現手順の検証（NG 提出物の監査） | `test-report` |

### 文脈別の起動構成

| 起動スキル | 文脈 | 起動エージェント | 起動形態 |
|-----------|------|----------------|---------|
| `test-analyze` | 解析材料の自己チェック（analysis.yaml / target-analysis.md が対象。Phase 1.5） | source-analyst | 単独 |
| `test-design` | テスト計画・ケース設計の妥当性確認 | test-architect | 単独 |
| `test-review` | 設計レビュー（test-cases.yaml が対象） | coverage-reviewer / feasibility-reviewer / user-perspective-reviewer | **3 並列** |
| `test-review` | 結果レビュー（実行結果・欠陥が対象） | defect-analyst / user-perspective-reviewer | **2 並列** |
| `test-report` | 報告書生成前の最終監査 | evidence-auditor | 単独 |

## 2. 起動方式

- **Agent ツール**で起動する。`subagent_type` は `deep-test:<agent-name>` 形式で指定し、プラグインルート `agents/` 配下のエージェント定義を参照させる
- エージェント定義（`agents/<agent-name>.md`）の frontmatter（tools / model）がそのまま適用される

```
Agent({
  subagent_type: "deep-test:coverage-reviewer",
  description: "テストケース網羅性レビュー",
  prompt: "<節 4 のガイドに従って組み立てたプロンプト>"
})
```

## 3. 並列起動の原則

- **同一文脈のレビューエージェントは 1 メッセージ内で複数の Agent ツールコールとして並列起動**する
- 各エージェントは独立した観点で評価し、相互の結果には依存しない
- 結果の統合（重複指摘の統合・矛盾の整理・PASS / NEEDS REVISION 判定）は**起動元スキルの責務**。エージェント自身に総合判定をさせない

```
# 設計レビュー文脈の並列起動例（test-review）
Agent({ subagent_type: "deep-test:coverage-reviewer",         description: "網羅性レビュー",       prompt: "..." })
Agent({ subagent_type: "deep-test:feasibility-reviewer",      description: "実行可能性レビュー",   prompt: "..." })
Agent({ subagent_type: "deep-test:user-perspective-reviewer", description: "ユーザー目線レビュー", prompt: "..." })
```

> 補足: 並列が許されるのは**レビューエージェント**である。実行スキル（`test-run-*`）の起動はブラウザセッション共有の制約により逐次が既定（`execution-policy.md`）であり、本原則とは別扱い。

## 4. プロンプト組み立てガイド

### 4.1 共通で渡す入力

| 入力 | 内容 |
|------|------|
| 対象の説明 | テスト対象（アプリケーション・機能）の概要と target-slug |
| テスト計画のパス | `.claude/.local/plugins/deep-test/{target-slug}/test-plan.md` |
| テストケースのパス | `.claude/.local/plugins/deep-test/{target-slug}/test-cases.yaml` |
| references 参照指示 | 読むべき共通 references の絶対参照（`${CLAUDE_PLUGIN_ROOT}/references/...`）と、その参照で確認すべき観点 |

エージェントは独立コンテキストで動作するため、パスはすべて解決済みの形（実際の target-slug を埋めた形）で渡すこと。

### 4.2 エージェント別の追加入力

| エージェント | 追加で渡す入力 |
|------------|---------------|
| source-analyst | 対象の説明・target-slug・解決済みの `analysis.yaml` / `target-analysis.md` のパス・`target_type` / `source_availability`（解析可能性の縮退状態）・`yaml-schema-analysis.md` の参照指示 |
| test-architect | 対象分析結果（技術スタック・画面/API 一覧）・要件/仕様情報・想定テストレベルの選定案・破壊的操作を含むケースへの `destructive: true` 付与の妥当性・`test-levels.md` の参照指示 |
| coverage-reviewer | 要件・仕様への参照（ケースの requirement 対応付け）・`test-levels.md` の主な確認観点の参照指示 |
| feasibility-reviewer | 実行環境情報（`test-setup` の検出結果: Playwright MCP / テストランナー / 外部接続可否）・`execution-policy.md` の参照指示 |
| user-perspective-reviewer | 業務シナリオ・ユーザー要件。結果文脈では実行結果サマリ（レベル別集計・fail 概要）も渡す |
| defect-analyst | fail 全件の defect 詳細（test-results.yaml からの抜粋）・エビデンスのパス一覧・`severity-policy.md` の参照指示 |
| evidence-auditor | fail 全件の defect 詳細・`evidence/{run_id}/{case_id}/` 配下の実ファイルパス一覧・整合性チェック（validate）の結果・`evidence-policy.md` の参照指示 |

### 4.3 共通注入事項（全エージェントプロンプトに必須）

以下のブロックを**すべてのエージェントのプロンプトに必ず含める**。

```text
## 共通規範（必須遵守）
- 各指摘・評価には信頼度 0〜100 を付与すること
- 未実施・未確認の項目を「問題なし」と書かないこと。未確認は「未確認」と明記する
- 欠陥重要度（severity）は ${CLAUDE_PLUGIN_ROOT}/references/severity-policy.md の基準でのみ判定すること
- エビデンス・再現手順・検証データの要件は ${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md に準拠すること
```

### 4.4 出力に求める形式（プロンプトに明記する）

各エージェントには以下の構造で返答させる。

| セクション | 内容 |
|-----------|------|
| 指摘リスト | 指摘ごとに: 対象（ケース ID / 欠陥 / エビデンス） / 指摘内容 / 根拠 / severity（欠陥に関する指摘のみ） / **信頼度（0〜100）** / 推奨対応 |
| 所見 | 担当観点での総合所見。PASS 相当 / NEEDS REVISION 相当の**意見**として述べる（最終判定は起動元スキルの責務） |
| 未確認事項 | 入力不足・環境制約等で評価できなかった項目の明示 |

## 5. 結果の取り扱い（起動元スキルの責務）

- 各エージェントの結果は**要約して**取り込み、生の全文を保持し続けない
- 同一趣旨の指摘は最も適切な 1 件に統合し、出所エージェントを併記する
- エージェント間で矛盾する指摘は両論を保持し、スキルの判定材料（必要ならユーザー提示）とする
- 信頼度は統合時の優先順位付けに用いる（低信頼の指摘を高信頼の指摘と同列に扱わない）
- `test-review` は統合結果から PASS / NEEDS REVISION を判定する。`test-report` は evidence-auditor の監査結果を最終バリデーションの判定材料とし、欠落検出時は報告書生成を中断して差し戻す
