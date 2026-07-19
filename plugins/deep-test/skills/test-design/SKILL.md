---
name: test-design
description: Phase 1.5 の test-analyze が生成した解析材料（analysis.yaml）を消費し、テスト計画（test-plan.md）とテストケース（test-cases.yaml）を設計・決定するフェーズスキル。8 テストレベルから対象レベルを選定し、境界値・同値分割・異常系を含む Playwright 実行可能なケースを yaml-schema 準拠で生成し、test-architect で自己チェックする。更新は revision 規則で版管理する。test オーケストレータから委譲された時、または「テスト計画を作って」「テストケースを設計して」と依頼された時に使用。
allowed-tools:
  - Read
  - Grep
  - Glob
  - Write
  - Edit
  - AskUserQuestion
  - Bash(date *)
  - Agent(deep-test:test-architect)
  # 大規模対象の調査を汎用調査エージェントへ委譲する場合（必要に応じて追加）:
  # - Agent(Explore)
---

# test-design スキル

テスト対象を分析し、テスト計画（test-plan.md）・対象レベル選定・テストケース設計（test-cases.yaml）までを一貫して行うフェーズスキル。
生成したケースはすべて `review_status: draft` であり、`test-review`（設計文脈）の承認を経てはじめて実行対象になる。

## 責務

| # | 責務 | 概要 |
|---|------|------|
| 1 | 解析材料の消費（対象理解） | Phase 1.5 の `test-analyze` が生成した `analysis.yaml`（`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-analysis.md` 準拠）を消費し、機能・画面・API・外部 IF 構成・リスク・ホットスポットを設計へ反映する。未生成時のみ軽量な補完分析を行う（Read / Glob / Grep。大規模時は調査エージェントへ委譲可）。二重分析を避け、対象理解の SSOT は analysis.yaml に一元化する。加えて Phase 1.6 の `test-fixture` が生成した `fixtures.yaml`（存在時・`${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md` 準拠）も参照し、各ケースの `fixtures:` と `automation: playwright-test` 指定の材料にする（非存在時は従来どおり `automation: playwright`＝探索的 MCP を既定とする） |
| 2 | テストレベル選定 | 8 テストレベル（`${CLAUDE_PLUGIN_ROOT}/references/test-levels.md`）から対象レベルを選定する。未指定時は分析結果から提案し、対話時は AskUserQuestion で確定する |
| 3 | test-plan.md 生成 | 対象概要・テスト方針・レベル別スコープ・環境前提・データ方針・スケジュール目安を記載した計画を `{target-slug}/` 直下に生成する |
| 4 | test-cases.yaml 生成・更新 | `${CLAUDE_PLUGIN_ROOT}/references/yaml-schema.md`（共通規約）と `yaml-schema-cases.md`（ケーススキーマ）に完全準拠でケースを生成する。既存ファイルの更新は revision 規則（+1・draft 戻し・deprecated 論理削除）を遵守する |
| 5 | 自己チェック | test-architect エージェント（`${CLAUDE_PLUGIN_ROOT}/references/agents.md`）で計画・レベル選定・ケースの妥当性を確認し、重大指摘を反映してから返却する |

## 責務外（他スキルが担当）

| 責務外 | 担当 |
|-------|------|
| 環境構築・検証（Playwright MCP・ランナー・venv） | `test-setup` |
| ケースの多観点レビュー・PASS / NEEDS REVISION 判定・承認（`review_status: approved` 化） | `test-review`（設計文脈） |
| テストの実行 | `test-run-*` 実行スキル 6 種 |
| 実績記録（test-results.yaml）・報告書生成 | オーケストレータ `test` / `test-report` |
| 設計レビューゲートの判定・修正ループ制御 | オーケストレータ `test`（`execution-policy.md` 1.1 章） |

## トリガー条件

起動するケース:

- オーケストレータ `test` から Skill ツール経由で委譲された場合（フルフローの design フェーズ、design-only モード、設計レビュー NEEDS REVISION 後の修正）
- 「テスト計画を作って」「テストケースを設計して」「テストケースを追加・更新して」と依頼された場合

起動しないケース:

- 設計済みケースのレビュー・承認を求められた場合（`test-review` の責務）
- テストの実行・再テストを求められた場合（`test-run-*` / オーケストレータの責務）
- ユニットテストのテストコード実装を求められた場合（本スキルはケース定義の設計であり、テストコードの実装は対象外）

## 前提

- `${CLAUDE_PLUGIN_ROOT}/references/` の共通規範（test-levels.md / yaml-schema.md / yaml-schema-analysis.md / agents.md / execution-policy.md / data-locations.md）が存在すること
- test-architect エージェント定義がプラグインルート `agents/` に存在すること

受け取る引数:

| 引数 | 内容 | 未指定時 |
|------|------|---------|
| `対象説明=` または位置引数 | テスト対象（アプリ URL・リポジトリパス・対象名） | 対話時は AskUserQuestion で確認。非対話時はエラー中断 |
| `spec=` | 仕様書パス（ファイルまたはディレクトリ） | 仕様書なしで分析（不明点は未確認事項へ） |
| `levels=` | 対象レベル（カンマ区切りの level 値） | 分析結果から提案して確定する |
| `target-slug=`（別名 `target=`） | 解決済み slug（委譲時にオーケストレータが渡す） | 単独時は `data-locations.md` 4 章の解決フローで解決する |
| `base=` | 基準ディレクトリ（委譲時に受領） | `data-locations.md` 1 章で解決する |
| `--non-interactive` | 非対話モード | 対話モード |

## 実行モード判定

| 判定条件 | モード | 動作 |
|---------|-------|------|
| 引数に `--non-interactive` を含む（委譲時はオーケストレータが付与） | 非対話 | レベル未指定時は分析提案を自動採用（採用根拠を返却に明記）。target-slug 解決は `data-locations.md` 4.2 章の非対話規則（複数既存 slug はエラー中断）に従う |
| 上記以外 | 対話 | レベル選定を AskUserQuestion（複数選択）で確定する。target-slug・対象の不足情報も AskUserQuestion で確認する |

## 実行フロー

詳細手順は `${CLAUDE_SKILL_DIR}/references/design-procedures.md`、ケース設計の原則は `${CLAUDE_SKILL_DIR}/references/case-design-principles.md` に従う。

### 1. 引数解釈・target-slug 確定
引数を解釈し、target-slug を確定する（委譲時は受領値、単独時は解決フロー）。

### 2. 対象分析
Phase 1.5 の `test-analyze` が生成した `analysis.yaml` を消費し、機能・画面・API・外部 IF・リスク・ホットスポットを設計材料として取り込む。未生成時のみ仕様書・リポジトリ・提供情報から機能・画面・API・外部 IF・データ構成を軽量に補完する（二重分析を避け、対象理解の SSOT は analysis.yaml に置く）。

### 3. テストレベル選定
`levels=` 指定があれば採用（明らかな不整合は警告）。無ければ提案を作成し、対話時は AskUserQuestion で確定、非対話時は自動採用する。

### 4. test-plan.md 生成
6 セクション構成で生成する。

### 5. test-cases.yaml 生成・更新
新規は全ケース `revision: 1` / `review_status: draft`、更新は revision 規則を遵守する。破壊的操作（データ削除・本番接続・外部送信等）を含むケースには `destructive: true` を付与する（`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md`）。`fixtures.yaml` が存在する場合、fixture 基盤を前提とする再現可能ケースには `fixtures:`（使用フィクスチャ名 = `fixtures.yaml` の `fixtures[].name`）と `automation: playwright-test` を指定する（fixture 基盤がないケースは従来の `automation: playwright`＝探索的 MCP のまま。使い分けは `${CLAUDE_SKILL_DIR}/references/case-design-principles.md`）。

### 6. 自己チェック
test-architect による自己チェックを実施し、重大指摘を計画・ケースへ反映する。

### 7. 返却
検証チェックリストを通過させ、設計結果を返却する。

## 検証

返却前に以下を確認する。未達成の項目は解消してから返却する。

- [ ] test-cases.yaml が yaml-schema.md / yaml-schema-cases.md に準拠している（必須フィールド完備・ID 形式 `TC-{LEVEL}-{3桁}`・ID の LEVEL トークンと level 値の対応・timeout_sec の付与）
- [ ] 新規作成・内容変更したケースの `review_status` が `draft` である（自ら approved にしていない）
- [ ] 各レベルに境界値・同値分割・異常系のケースが含まれている（case-design-principles.md）
- [ ] `automation: playwright` のケースの steps が Playwright 実行可能性基準を満たしている
- [ ] preconditions / postconditions でテストデータの前提宣言と復元を設計している（execution-policy.md 5 章）。破壊的操作を含むケースは明示している（同 6 章）
- [ ] 既存更新時: ID 改変なし・変更ケースのみ revision +1 と draft 戻し・削除は deprecated 論理削除のみ（yaml-schema-cases.md 3 章）
- [ ] test-architect の自己チェックを実施し、重大指摘を反映した（プロンプトに共通注入事項を含めた）
- [ ] test-plan.md が 6 セクション（対象概要・テスト方針・レベル別スコープ・環境前提・データ方針・スケジュール目安）を含んでいる
- [ ] test-results.yaml に書き込んでいない

## 引き渡し（オーケストレータへの返却内容）

最終応答に以下の設計結果サマリを含めて返却する。

```markdown
## テスト設計結果（test-design）

- target-slug: <slug> / 生成・更新ファイル: test-plan.md / test-cases.yaml（絶対パス併記）
- 選定レベルと選定根拠（未指定→提案採用の場合はその旨）

| レベル | 新規 | 更新（revision +1） | deprecated | 有効ケース計 |
|-------|------|--------------------|-----------|-------------|

- test-architect 自己チェック所見: 反映済み指摘 / 反映不要と判断した指摘（理由付き）
- 未確認事項: 分析で確認できなかった仕様・環境情報（なければ「なし」）
- 次フェーズ: 全ケース draft のため test-review（設計文脈）の承認が必要
```

## 重要な制約

- `test-results.yaml` への書き込み・編集をしない
- ケース ID の改変・deprecated ID の別ケースへの再利用・ケースの物理削除をしない（yaml-schema.md 2.2 章・yaml-schema-cases.md 3 章）
- `review_status` を自ら `approved` にしない。新規作成・内容変更したケースは `draft` とする（承認は test-review〔設計文脈〕PASS のみ。内容変更のない既存ケースの approved は維持してよい）
- テストの実行・レビュー判定（PASS / NEEDS REVISION）を行わない
- test-architect には評価のみをさせ、成果物の修正はさせない（agents.md 冒頭の構造規範）。指摘の反映は本スキルが行う
- 破壊的操作（データ削除・更新・外部送信）を含むケースは steps / preconditions に明示する（execution-policy.md 6 章）
- 機微情報（パスワード・トークン等）の実値を data / steps に書かない（値の取得方法・格納場所を書く。evidence-policy.md 5 章）

## 参照

| 参照先 | 内容 |
|-------|------|
| `${CLAUDE_PLUGIN_ROOT}/references/common-references.md` | プラグイン共通規範の集約インデックス（本スキルの場面別参照は 3.1 章「設計時」） |
| `${CLAUDE_SKILL_DIR}/references/design-procedures.md` | 分析 → 計画 → ケース設計 → 自己チェックの詳細手順 |
| `${CLAUDE_SKILL_DIR}/references/case-design-principles.md` | ケース設計原則（設計技法・レベル別観点・Playwright 実行可能性基準・検証データ設計） |
| `${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-analysis.md` | Phase 1.5 の `test-analyze` が生成する `analysis.yaml`（責務#1 で消費する対象理解の材料）のスキーマ SSOT |
| `${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md` | Phase 1.6 の `test-fixture` が生成する `fixtures.yaml`（責務#1 で参照）のスキーマ SSOT・`automation: playwright-test` / `cases[].fixtures` の使い分け規範 |
