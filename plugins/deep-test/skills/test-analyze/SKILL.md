---
name: test-analyze
description: テスト対象ソースを read-only で静的に理解し、下流が消費する解析材料（analysis.yaml / target-analysis.md）を生成する Phase 1.5 のフェーズスキル。決定は行わず提案（hint）に留める。責務外=ケース設計・レベル/技法/優先度決定（test-design が担当）、テスト実行・カバレッジ実測（test-run-* が担当）。test 委譲時や「テスト対象を解析して」「解析材料を作って」「テスト対象のリスクを洗い出して」と依頼時に使用。Use when analyzing a test target for deep-test.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Write
  - AskUserQuestion
  - Bash(git log *)
  - Bash(git diff *)
  - Bash(git shortlog *)
  - Bash(date *)
  - Agent(deep-test:source-analyst)
  # 存在時のみ利用する複雑度計測ツール（read-only。無ければ measured:false）:
  # - Bash(radon *)
  # - Bash(lizard *)
  # 大規模対象の調査を汎用調査エージェントへ委譲する場合（必要に応じて追加）:
  # - Agent(Explore)
---
<!-- TEST-ANALYZE-SKILL-SENTINEL-v1 -->

# test-analyze スキル

テスト対象ソースを read-only で静的理解し、下流が消費する**材料（evidence）** = 機械可読 `analysis.yaml` + 人間可読 `target-analysis.md` を生成する Phase 1.5 フェーズスキル。test-design がこれを材料に**レベル / 技法 / 優先度 / ケースを決定する**（本スキルは決定の直前で止まる）。

## 責務

| # | 責務 | 概要 |
|---|------|------|
| 1 | アーキ・技術スタック把握 | 言語 / フレームワーク / レイヤー / ビルド・実行基盤を構造化 |
| 2 | 依存グラフ・エントリポイント抽出 | import / 呼出関係と HTTP ルート / API / CLI / メッセージ購読 / スケジュールジョブ / UI 画面 / 公開関数を列挙 |
| 3 | 複雑度・変更頻度（ホットスポット） | 循環的複雑度（計測ツール有時のみ）× git churn で高リスク Top N を特定。ツール無しは `measured: false` |
| 4 | 既存テスト資産分析 | 既存テストの枠組み / 対象 / 粒度を要約し疑わしい空白を推定 |
| 5 | テスタビリティ評価 | DI 欠如 / グローバル状態 / 隠れ I/O / 非決定性 / 時刻結合と seam 候補を検出 |
| 6 | 変更影響分析（`diff=` 時） | 変更ファイル → 依存逆引き → 影響モジュール / EP と回帰スコープ候補を算出（**提案のみ**） |
| 7 | 仕様乖離検出（`spec=` 時） | 主要ルート / ルールを仕様と粗く突合し乖離を記録 |
| 8 | 対象種別判定 | web-app / api / batch / library / data-pipeline / cli / mixed / unknown を判定 |
| 9 | リスクレジスタ算出 | likelihood（複雑度 / churn / 外部依存）× impact（露出 / 業務重要度）で risk_level を算出（ISTQB product risk） |
| 10 | 攻撃面・軽量脅威モデリング | 公開 EP・信頼境界から STRIDE 6 分類の静的所見を付与 |
| 11 | カバレッジ観点の提示 | 必要網羅基準（statement / branch 等）と計測コマンド案を提示（**実測はしない**） |
| 12 | 品質特性マッピング | ISO/IEC 25010:2023 の 9 特性を対象・EP から判定し材料化 |
| 13 | 自己チェック | `source-analyst` エージェント（`${CLAUDE_PLUGIN_ROOT}/references/agents.md`）で材料の網羅性・根拠妥当性を単独レビューし重大指摘を反映 |

## 責務外（他スキルが担当）

| 責務外 | 担当 |
|-------|------|
| テストケース設計・技法適用・レベル選定・優先度決定 | `test-design` |
| テスト計画（test-plan.md）の生成 | `test-design` |
| テストコード基盤（fixture）の構築 | `test-fixture`（Phase 1.6） |
| テスト実行環境（Docker）の構築 | `test-environment`（Phase 1.7） |
| レビュー判定・承認（`review_status: approved` 化） | `test-review` |
| テストの実行・**カバレッジの実測** | `test-run-*`（カバレッジの実測は現状 deep-test 未実装の将来拡張。本スキルは責務#11 のとおり必要網羅基準・計測コマンド案の提示に留める） |
| 動的セキュリティ検査 | `test-run-security`（本スキルは静的な攻撃面把握のみ） |
| 実績記録（test-results.yaml）・報告書生成 | オーケストレータ `test` / `test-report` |

## トリガー条件

起動する:

- オーケストレータ `test` から Skill ツール経由で委譲（フルフローの Phase 1.5 analyze フェーズ、変更影響分析 / 仕様乖離検出の依頼）
- 「テスト対象を解析して」「解析材料を作って」「テスト対象のリスクを洗い出して」と依頼された

起動しない:

- テストケース・テスト計画の設計を求められた（`test-design` の責務）
- 材料を使ったレベル / 技法 / 優先度の**決定**を求められた（`test-design` の責務。本スキルは決定の直前で止まる）
- テストの実行・カバレッジ実測を求められた（`test-run-*` の責務）
- 設計済み成果物のレビュー・承認を求められた（`test-review` の責務）

## 前提

- `${CLAUDE_PLUGIN_ROOT}/references/` の共通規範（yaml-schema-analysis.md / data-locations.md / agents.md / execution-policy.md）が存在する
- `source-analyst` エージェント定義がプラグインルート `agents/` に存在する
- Bash は read-only の git 読み取り（`git log` / `git diff` / `git shortlog`）と**存在する場合のみ**複雑度計測ツール（radon / lizard 等）に限定。SUT のプロダクションコードへは書き込まない（書き込み境界厳守）

受け取る引数:

| 引数 | 内容 | 未指定時 |
|------|------|---------|
| `対象説明=` または位置引数 | テスト対象（アプリ URL・リポジトリパス・対象名） | 対話時は AskUserQuestion で確認。非対話時はエラー中断 |
| `spec=` | 仕様書パス（ファイルまたはディレクトリ） | 仕様なしで解析（乖離検出はスキップし未確認事項へ） |
| `target-slug=`（別名 `target=`） | 解決済み slug（委譲時にオーケストレータが付与） | 単独時は `data-locations.md` 4 章の解決フロー |
| `base=` | 基準ディレクトリ（委譲時に受領） | `data-locations.md` 1 章で解決 |
| `diff=` | 変更影響分析の対象差分（git ref / 範囲） | 変更影響分析をスキップ |
| `--non-interactive` | 非対話モード | 対話モード |

> 上流連携: `test-setup`（Phase 1）検出のランナー・複雑度 / カバレッジツール情報を利用可能なら受領しツール有無判定に用いる。無ければ自力検出。

## 実行モード判定

| 判定条件 | モード | 動作 |
|---------|-------|------|
| 引数に `--non-interactive` を含む（委譲時はオーケストレータが付与） | 非対話 | 曖昧確認せず進行。target-slug は `data-locations.md` 4.2 章の非対話規則（唯一の既存 slug 採用・複数はエラー中断）に従う |
| 上記以外 | 対話 | 対象・target-slug の不足を AskUserQuestion で確認 |

## 実行フロー

詳細手順は `${CLAUDE_SKILL_DIR}/references/procedures.md`、エージェント運用は `${CLAUDE_SKILL_DIR}/references/agents.md` に従う。本スキルは deep-test ライフサイクルの **Phase 1.5**（`test-setup` の後・`test-design` の前）。

### 1. 引数解釈・target-slug 確定
引数を解釈し target-slug を確定（委譲時は受領値、単独時は解決フロー）。

### 2. source_availability 判定
ソース取得可否を `full` / `partial` / `none` で判定（縮退動作の分岐キー。yaml-schema-analysis.md 16 章）。

### 3. 材料の生成
`source_availability` に応じ責務 1〜12 を解析。`full` は全解析、`partial` は取得可能範囲を解析し欠落を `open_questions` へ、`none` はコードベース解析（複雑度・churn・依存グラフ・seam）をスキップし spec / 公開仕様から静的導出（`confidence: low`）。数値は計測ツールが無ければ `measured: false` + `null`（捏造禁止）。

### 4. 出力生成
`{target-slug}/analysis.yaml`（機械可読・yaml-schema-analysis.md 準拠）と `{target-slug}/target-analysis.md`（人間可読）を Write で生成。配置は `data-locations.md` 準拠。

### 5. 自己チェック
`source-analyst` エージェントを単独起動し材料の網羅性・根拠妥当性・誠実性をレビューさせる。重大指摘を材料へ反映（反映は本スキルが行い、エージェントには修正させない）。

### 6. 返却
検証チェックリストを通過させ解析結果サマリを返却。

## 検証

返却前に以下を確認する。未達成の項目は解消してから返却する。

- [ ] analysis.yaml が yaml-schema-analysis.md に準拠している（meta 必須フィールド・ID 形式 `EP-` / `HS-` / `TF-` / `RISK-`・enum 値）
- [ ] `source_availability`（full / partial / none）と各セクション充足度・`confidence`・target-analysis.md の縮退明示が整合している
- [ ] 複雑度・churn の未計測箇所を `measured: false` + `null` で誠実に記録した（未計測値を実測のように書いていない）
- [ ] 取得できなかった情報・推定を `open_questions` に記録した（捏造していない）
- [ ] risk_register の `suggested_focus` 等が hint に留まり、レベル / 技法 / 優先度 / ケースを確定していない
- [ ] `spec=` 未指定時に `spec_divergence` を、`diff=` 未指定時に `change_impact` を出力していない
- [ ] source-analyst の自己チェックを実施し、重大指摘を反映した（プロンプトに共通注入事項を含めた）
- [ ] test-results.yaml / test-cases.yaml / test-plan.md に書き込んでいない

## 引き渡し（オーケストレータへの返却内容）

最終応答に以下の解析結果サマリを含めて返却する。

```markdown
## ソース解析結果（test-analyze）

- target-slug: <slug> / 生成ファイル: analysis.yaml / target-analysis.md（絶対パス併記）
- 対象種別: <target_type> / ソース取得可否: <source_availability>

| セクション | 件数 | 特記 |
|-----------|------|------|
| entry_points | <n> | 公開 EP 数 |
| hotspots | <n> | measured 実測 / 推定の別 |
| risk_register | <n> | risk_level=high の件数 |
| testability_findings | <n> | 主要 seam 提案 |

- source-analyst 自己チェック所見: 反映済み指摘 / 反映不要と判断した指摘（理由付き）
- open_questions（未確認事項）: 縮退・取得不能で確認できなかった事項（なければ「なし」）
- 次フェーズ: analysis.yaml を材料に test-design がレベル / 技法 / 優先度 / ケースを決定する
```

## 重要な制約

- read-only の静的理解に徹し、SUT のプロダクションコードへ書き込まない（書き込み境界厳守）。稼働アプリへの能動プローブをしない（動的探索は `test-run-*` / `test-setup` の責務）
- **決定をしない**: テストレベル選定・技法選定・優先度決定・ケース設計を行わない。risk_register の `suggested_focus` 等は hint に留め、決定の直前で止まる（決定は `test-design` の専有）
- **捏造禁止**: 複雑度・churn の数値は計測ツールが無ければ `measured: false` + `null`。確認できない EP・依存・乖離を断定しない。取得できなかった情報は `open_questions` に必ず記録する
- 縮退（`source_availability` partial / none）時は `confidence: low` を付与し、縮退したセクションを target-analysis.md に「縮退（ソース不在）」と明示する
- `test-results.yaml` / `test-cases.yaml` / `test-plan.md` への書き込み・編集をしない（材料 analysis.yaml / target-analysis.md のみを生成する）
- 他 worker スキルを呼ばない（逆呼び出し禁止）。自エージェント `source-analyst` と read-only ツールのみ使用する（2 段委譲を厳守）
- source-analyst には評価のみをさせ、材料の修正はさせない（指摘の反映は本スキルが行う。agents.md 冒頭の構造規範）
- リスクの二軸を混同しない: risk_register の product risk（likelihood × impact）は `severity-policy.md` の severity（欠陥の本番影響度）とは別概念。analysis.yaml に severity は持たない（yaml-schema-analysis.md 10 章）

## 参照

| 参照先 | 内容 |
|-------|------|
| `${CLAUDE_PLUGIN_ROOT}/references/common-references.md` | プラグイン共通規範の集約インデックス（本スキルの場面別参照は 3.6 章「解析時」） |
| `${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-analysis.md` | analysis.yaml の完全スキーマ SSOT（enum・ID 形式・縮退動作・リスク二軸注記） |
| `${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` | analysis.yaml / target-analysis.md の配置パス・target-slug 解決フロー |
| `${CLAUDE_PLUGIN_ROOT}/references/agents.md` | source-analyst の選定・起動方式・プロンプト組み立て・共通注入事項 |
| `${CLAUDE_SKILL_DIR}/references/procedures.md` | 入力解決 → 縮退判定 → 材料生成 → 自己チェックの詳細手順 |
| `${CLAUDE_SKILL_DIR}/references/agents.md` | 本スキルのフェーズ定義（source-analyst の起動フェーズ） |
