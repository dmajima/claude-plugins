<!-- YAML-SCHEMA-ANALYSIS-SENTINEL-v1 -->
# analysis.yaml スキーマ（yaml-schema-analysis）

`analysis.yaml`（test-analyze が生成するテスト対象理解の材料）の完全スキーマを定義する SSOT である（`yaml-schema.md` のスキーマ定義群ハブから参照される analysis 系スキーマ）。
`analysis.yaml` は test-analyze（Phase 1.5）が対象ソースの read-only 静的理解の結果として生成する **機械可読の材料（evidence）** であり、下流スキル（test-design / test-fixture〔将来〕 / test-review〔coverage-reviewer〕 / test-run-security / test-run-unit ほか / test-report）が **単方向に消費** する。
生成主体は test-analyze の LLM（Write で直接生成）であり、`test-results.yaml`（results_manager.py 経由）とは別系統である。test-analyze は `test-results.yaml` / `test-cases.yaml` に一切書き込まない。
共通の YAML 記述規約（UTF-8・スペース 2・ISO8601 等）は `yaml-schema.md` 2.1 を継承する。フィールド・enum 値の追加・変更・改廃は本ファイルを起点に行い、他 references・スキルへは参照のみで内容を複製しない。

---

## 1. 位置付けと参照方向

- analysis.yaml のフィールド・enum 値・スキーマ構造を定義する場所は本ファイルのみとする（唯一の SSOT）
- 下流スキルは本スキーマを **読み取り専用で消費** し、analysis.yaml を書き換えない（材料の一次生成は test-analyze の専有）
- `meta.source_availability`（`full` / `partial` / `none`）を **縮退動作の分岐キー** とする（16 章）。ソースが取得できない場合でも推定値を捏造せず、欠落は `open_questions` に必ず記録する
- test-analyze は決定（テストレベル選定・技法選定・優先度決定・ケース設計）を行わない。`risk_register` の `suggested_focus` 等はすべて **提案（hint）** であり、決定は test-design の専有である
- 本スキーマは severity（欠陥の本番影響度）を持たない。リスクの二軸の区別は 10 章のリスク二軸注記を参照

## 2. 代表スキーマ（全体像）

```yaml
meta:
  schema_version: 1
  target_slug: <slug>
  analyzed_at: <ISO8601>
  analyzer: test-analyze
  source_availability: full | partial | none   # 縮退動作の分岐キー
  target_type: web-app | api | batch | library | data-pipeline | cli | mixed | unknown
  base_ref: <git ref | null>
  diff_ref: <git ref | null>
  spec_provided: true | false
architecture:
  languages: [ ... ]
  frameworks: [ ... ]
  layers: [ { name, responsibility } ]
  build_run: [ ... ]
entry_points:
  - id: EP-001
    kind: http-route | api | cli | message-consumer | scheduled-job | ui-page | public-function
    signature: <path/method/name>
    exposure: public | authenticated | internal
    auth: none | session | token | ...
    source_ref: <file:line>
dependency_summary:
  internal_module_count: <n>
  key_edges: [ "moduleA -> moduleB", ... ]
  external_dependencies: [ { name, kind: db|http|queue|fs|thirdparty, usage } ]
hotspots:
  - id: HS-001
    location: <file|module>
    cyclomatic_complexity: <n | null>   # ツール無ければ null + measured:false
    churn: <commits_in_window | null>
    measured: true | false
    rationale: <なぜリスクか>
existing_tests_summary:
  frameworks: [ ... ]
  test_file_count: <n>
  covered_areas_estimated: [ ... ]
  gaps_suspected: [ ... ]
testability_findings:
  - id: TF-001
    concern: di-missing | global-state | hardcoded-dependency | hidden-io | nondeterminism | time-coupling
    location: <file:line>
    impact: <自動テストをどう阻害するか>
    seam_suggestion: <任意>
risk_register:
  - id: RISK-001
    item: <機能/モジュール>
    likelihood: high | medium | low
    likelihood_basis: [ complexity, churn, external-deps, ... ]
    impact: high | medium | low
    impact_basis: [ exposure, business-importance(推定 or spec/user), ... ]
    risk_level: high | medium | low       # likelihood × impact（ISTQB product risk）
    quality_characteristics: [ functional-suitability, security, reliability, ... ]  # ISO 25010:2023 の 9 特性
    suggested_focus: [ level_hint, technique_hint ]   # 提案のみ・決定は test-design
    confidence: high | medium | low
attack_surface_summary:
  public_entry_points: [ EP-ids ]
  trust_boundaries: [ ... ]
  stride_notes: [ { category: spoofing|tampering|repudiation|info-disclosure|dos|elevation, note } ]
coverage_viewpoints:
  measurable_in_this_env: true | false
  proposed_commands: [ "pytest --cov=...", "jest --coverage", "JaCoCo", "go test -cover", ... ]  # 提案のみ
  criteria_hint: [ statement, branch, ... ]   # リスクに応じ推奨。MC/DC は高信頼性対象のみ
spec_divergence:            # spec= 指定時のみ
  - { spec_ref, code_ref, finding, confidence }
change_impact:             # diff= 指定時のみ
  changed_files: [ ... ]
  impacted_modules: [ ... ]
  impacted_entry_points: [ EP-ids ]
  suggested_regression_scope: [ ... ]   # 提案のみ
open_questions: [ ... ]    # 未確認事項（捏造しない・必ず記録）
```

### 2.1 YAML 記法の遵守（実体化時の必須事項）

`analysis.yaml` は下流スキルが機械可読で消費する SSOT であり、代表スキーマのプレースホルダ（`<...>`）を実際の値へ実体化した結果は **必ず妥当な（parse 可能な）YAML** でなければならない（parse 不能は不許容）。

- 自由記述の文字列値（`rationale` / `responsibility` / `signature` / `note` / `build_run` / `finding` / `impact` 等）で、`:`（コロン）・`` ` ``（バッククォート）・`<` `>` `#` `[` `]` `{` `}` を含む、または先頭が `-` / `?` / `@` 等で始まるものは、**ダブルクォートで囲む**か `>-` / `|-` ブロックスカラーで表現する
- 特にコマンド例・コード断片（バッククォート付き）は値全体をダブルクォートする。未クォートのバッククォートや、`key: ` と誤認される `:` は ScannerError を招く
- 本スキーマ内の例でバッククォートやコロンを含む値を書く場合は、次のように **クォート済みの形** で示す（誤誘導防止）:

```yaml
architecture:
  build_run:
    - "ビルド不要（インタプリタ実行）。`python results_manager.py <subcommand> ...`"
    - "report: `python generate_excel.py ...`（markdown 同様）"
```

## 3. meta

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `schema_version` | integer | 必須 | スキーマ版数。現行 `1`。非互換変更時は本ファイルの改訂とセットでインクリメントする |
| `target_slug` | string | 必須 | 解決済み target-slug（解決フローは `data-locations.md`） |
| `analyzed_at` | string（ISO8601） | 必須 | 解析実施日時 |
| `analyzer` | string | 必須 | 生成スキル名。固定値 `test-analyze` |
| `source_availability` | enum `full` / `partial` / `none` | 必須 | ソース取得可否。縮退動作の分岐キー（16 章） |
| `target_type` | enum `web-app` / `api` / `batch` / `library` / `data-pipeline` / `cli` / `mixed` / `unknown` | 必須 | 対象種別判定の結果 |
| `base_ref` | string または `null` | 任意 | 基準 git ref（委譲時に受領。無ければ `null`） |
| `diff_ref` | string または `null` | 任意 | 変更影響分析の対象差分（`diff=` 指定時のみ。無指定は `null`） |
| `spec_provided` | boolean | 必須 | 仕様書が入力されたか（`spec=` 指定の有無） |

## 4. architecture

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `languages` | list[string] | 任意 | 検出した言語 |
| `frameworks` | list[string] | 任意 | 検出したフレームワーク |
| `layers` | list[{ `name`, `responsibility` }] | 任意 | レイヤー構成（名称と責務） |
| `build_run` | list[string] | 任意 | ビルド・実行基盤（ビルドツール・実行コマンド等） |

## 5. entry_points[]

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `id` | string | 必須 | エントリポイント ID。`EP-{3桁連番}` 形式（例: `EP-001`）。発番後は改変禁止 |
| `kind` | enum `http-route` / `api` / `cli` / `message-consumer` / `scheduled-job` / `ui-page` / `public-function` | 必須 | エントリポイント種別 |
| `signature` | string | 必須 | 識別子（パス / メソッド / 関数名など） |
| `exposure` | enum `public` / `authenticated` / `internal` | 必須 | 露出度 |
| `auth` | string（例: `none` / `session` / `token` ...） | 任意 | 認証方式 |
| `source_ref` | string | 任意 | 出所（`file:line`）。捏造せず、確認できた範囲で記載 |

## 6. dependency_summary

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `internal_module_count` | integer | 任意 | 内部モジュール数 |
| `key_edges` | list[string] | 任意 | 主要な依存エッジ（`"moduleA -> moduleB"` 形式） |
| `external_dependencies` | list[{ `name`, `kind`, `usage` }] | 任意 | 外部依存。`kind` は `db` / `http` / `queue` / `fs` / `thirdparty` |

## 7. hotspots[]

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `id` | string | 必須 | ホットスポット ID。`HS-{3桁連番}` 形式（例: `HS-001`） |
| `location` | string | 必須 | 対象（`file` または `module`） |
| `cyclomatic_complexity` | integer または `null` | 必須 | 循環的複雑度。計測ツールが無ければ `null` とし `measured: false` を厳守（捏造禁止） |
| `churn` | integer または `null` | 必須 | 変更頻度（対象期間内のコミット数）。取得不能時は `null` |
| `measured` | boolean | 必須 | 数値を実測したか。推定・不明時は `false`（`null` 数値と併用） |
| `rationale` | string | 必須 | なぜリスクか（複雑度 × churn 等の根拠） |

## 8. existing_tests_summary

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `frameworks` | list[string] | 任意 | 既存テストのフレームワーク |
| `test_file_count` | integer | 任意 | 既存テストファイル数 |
| `covered_areas_estimated` | list[string] | 任意 | カバー済みと推定される領域（推定である旨を保つ） |
| `gaps_suspected` | list[string] | 任意 | 疑わしい空白（欠落が疑われる領域） |

## 9. testability_findings[]

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `id` | string | 必須 | テスタビリティ所見 ID。`TF-{3桁連番}` 形式（例: `TF-001`） |
| `concern` | enum `di-missing` / `global-state` / `hardcoded-dependency` / `hidden-io` / `nondeterminism` / `time-coupling` | 必須 | 阻害要因の分類 |
| `location` | string | 必須 | 出所（`file:line`） |
| `impact` | string | 必須 | 自動テストをどう阻害するか |
| `seam_suggestion` | string | 任意 | seam（テスト用の差し込み点）候補の提案 |

## 10. risk_register[]

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `id` | string | 必須 | リスク ID。`RISK-{3桁連番}` 形式（例: `RISK-001`） |
| `item` | string | 必須 | 対象（機能 / モジュール） |
| `likelihood` | enum `high` / `medium` / `low` | 必須 | 発生確率 |
| `likelihood_basis` | list[string] | 任意 | 発生確率の根拠（`complexity` / `churn` / `external-deps` ...） |
| `impact` | enum `high` / `medium` / `low` | 必須 | 影響度 |
| `impact_basis` | list[string] | 任意 | 影響度の根拠（`exposure` / `business-importance`〔推定 or spec/user〕 ...） |
| `risk_level` | enum `high` / `medium` / `low` | 必須 | likelihood × impact（ISTQB product risk） |
| `quality_characteristics` | list[string]（ISO/IEC 25010:2023 の 9 特性） | 任意 | `functional-suitability` / `performance-efficiency` / `compatibility` / `interaction-capability` / `reliability` / `security` / `maintainability` / `flexibility` / `safety`（Testability は保守性の副特性） |
| `suggested_focus` | list[string] | 任意 | 重点候補の **提案のみ**（`level_hint` / `technique_hint`）。決定は test-design |
| `confidence` | enum `high` / `medium` / `low` | 必須 | 本リスク所見の確信度（縮退時は `low` を付与） |

> リスクの二軸注記（SSOT 衝突回避）: 本 `risk_register` の likelihood × impact（= **product risk**・テスト前の優先度付け）は、`severity-policy.md` が定義する severity（= **欠陥の本番影響度**・欠陥発見後）とは **別概念** である。両者を混同せず、analysis.yaml は severity-policy.md の enum・判定基準を **複製しない**。product risk はテスト設計の重点選定（test-design の材料）に、severity は検出済み欠陥の影響度評価（test-run-* / test-review の結果文脈）に用いる。

## 11. attack_surface_summary

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `public_entry_points` | list[string] | 任意 | 公開エントリポイントの ID 参照（`EP-ids`） |
| `trust_boundaries` | list[string] | 任意 | 信頼境界 |
| `stride_notes` | list[{ `category`, `note` }] | 任意 | STRIDE 軽量所見。`category` は `spoofing` / `tampering` / `repudiation` / `info-disclosure` / `dos` / `elevation`。動的検査は行わず静的な攻撃面把握のみ |

## 12. coverage_viewpoints

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `measurable_in_this_env` | boolean | 任意 | 当該環境でカバレッジ実測が可能か（実測は本スキルでは行わない） |
| `proposed_commands` | list[string] | 任意 | 計測コマンドの **提案のみ**（例: `pytest --cov=...` / `jest --coverage` / JaCoCo / `go test -cover`）。実行は test-run-* の責務 |
| `criteria_hint` | list[string] | 任意 | 推奨網羅基準の hint（`statement` / `branch` ...）。MC/DC は高信頼性対象のみ |

## 13. spec_divergence[]（`spec=` 指定時のみ）

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `spec_ref` | string | 必須 | 仕様側の参照（節番号・ファイル位置） |
| `code_ref` | string | 必須 | 実装側の参照（`file:line`） |
| `finding` | string | 必須 | 仕様と実装の乖離内容（粗い突合の所見） |
| `confidence` | enum `high` / `medium` / `low` | 必須 | 乖離所見の確信度 |

`spec=` 未指定時は本セクションを出力しない（乖離検出はスキップし、必要事項は `open_questions` へ）。

## 14. change_impact（`diff=` 指定時のみ）

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `changed_files` | list[string] | 必須 | 変更ファイル一覧 |
| `impacted_modules` | list[string] | 任意 | 依存逆引きで影響が及ぶモジュール |
| `impacted_entry_points` | list[string] | 任意 | 影響が及ぶエントリポイントの ID 参照（`EP-ids`） |
| `suggested_regression_scope` | list[string] | 任意 | 回帰スコープの **提案のみ**（決定は test-design / retest-policy.md 側） |

`diff=` 未指定時は本セクションを出力しない（変更影響分析はスキップ）。

## 15. open_questions

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `open_questions` | list[string] | 必須（空可） | 未確認事項。取得できなかった情報・推定にとどまる項目を **必ず記録** する。推定値の捏造は禁止 |

## 16. source_availability による縮退

`meta.source_availability` を分岐キーに、テスト対象がソースでない場合へ縮退する。推定値の捏造は禁止（`execution-policy.md` の SKIPPED 原則に整合）。

| `source_availability` | 状況 | 動作 |
|----------------------|------|------|
| `full` | ソース全面あり | 全解析（アーキ / 依存 / 複雑度 / churn / テスタビリティ / 既存テスト / 変更影響）を実施 |
| `partial` | 一部モジュール / 生成物のみ | 取得可能範囲を解析し、欠落を `open_questions` に明記。数値は `measured: false` を厳守 |
| `none` | ソースなし（仕様書のみ / デプロイ済み外部システム） | コードベース解析（複雑度・churn・依存グラフ・seam）を **スキップ**。EP は `spec=`・API ドキュメント・公開仕様から静的に導出（稼働アプリへの能動プローブはしない）。risk_register は弱く推定し `confidence: low` を付与。縮退したセクションは target-analysis.md に「縮退（ソース不在）」と明示する |

## 17. 関連 references

| 参照先 | 内容 |
|-------|------|
| `yaml-schema.md` | スキーマ定義群のハブ（本ファイルの親）。共通の YAML 記述規約・ID/採番規約 |
| `severity-policy.md` | 欠陥重要度 severity（本番影響度）の SSOT。`risk_register` の product risk とは別概念（10 章のリスク二軸注記） |
| `data-locations.md` | 配置パス規約・target-slug 解決フロー（analysis.yaml / target-analysis.md も本規約に準拠して `{target-slug}/` 直下へ配置） |
