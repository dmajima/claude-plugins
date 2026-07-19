# YAML スキーマ定義（test-cases.yaml / test-results.yaml）

deep-test プラグインが状態管理に用いる `test-cases.yaml`（テストケース定義）と `test-results.yaml`（実行実績）のスキーマ定義群の入口（ハブ）である。
本ファイルは両ファイル共通の記述規約（YAML 記述規約・ID/採番規約）と操作規約を SSOT として定義し、ファイル別の完全スキーマは以下の 2 ファイルに分割して定義する。
フィールド・enum 値の追加・変更・改廃は必ず本ファイル群（本ファイル + 分割先 2 ファイル）を起点に行い、他の references やスキルへは参照のみで内容を複製しない。

| スキーマ本体（分割先） | 内容 |
|----------------------|------|
| `yaml-schema-cases.md` | test-cases.yaml の完全スキーマ（meta / cases[] フィールド / revision・承認・削除の規則 / 記入例） |
| `yaml-schema-results.md` | test-results.yaml の完全スキーマ（meta / runs[] / results[] / defect / latest / status の使い分け / annotations / 記入例） |

なお、`analysis.yaml`（test-analyze が Phase 1.5 で生成する対象理解の材料）の analysis 系スキーマは、results_manager.py を経由しない**別系統**として `yaml-schema-analysis.md` に定義する（本ハブの分割先 2 ファイルには含めず、共通記述規約は 2 章を継承する）。
同様に、`environment.yaml`（test-environment が Phase 1.7 で生成するテスト用派生環境のマニフェスト）の environment 系スキーマは、results_manager.py を経由しない**別系統**として `yaml-schema-environment.md` に定義する（本ハブの分割先 2 ファイルには含めず、共通記述規約は 2 章を継承する）。

---

## 1. 対象ファイルと目的

| ファイル | 目的 | 生成・更新主体（詳細は 3 章） |
|---------|------|------------------------------|
| `test-cases.yaml` | テストケース定義。`revision` による版管理と `review_status` による承認管理を担う | `test-design` スキル |
| `test-results.yaml` | 実行実績。run 履歴の **append-only** 記録と `latest` 集計インデックス（ケースごとの最新結果への O(1) 参照）を担う | オーケストレータ `test`（results_manager.py 経由のみ） |

- 両ファイルの配置場所（`{target-slug}/` 直下）と基準ディレクトリは `data-locations.md` 参照
- 実績 YAML が状態の SSOT であり、報告書はここから何度でも再生成できる派生物である（`report-format.md`）

---

## 2. 共通記述規約

### 2.1 YAML 記述規約

- エンコーディングは UTF-8（BOM なし）
- 日本語は Unicode エスケープせず**そのまま記述**する（results_manager.py は PyYAML `allow_unicode=True` で書き出す前提）
- インデントはスペース 2。タブは使用しない
- 日時は ISO8601 形式・タイムゾーンオフセット付きを推奨（例: `2026-07-17T14:30:00+09:00`）
- エビデンス等の相対パスは `{target-slug}/` 直下を基準に記述する（例: `evidence/R20260717-143000/TC-FUNC-001/step-01.png`）

### 2.2 ID・採番規約

#### ケース ID: `TC-{LEVEL}-{3桁連番}`

| LEVEL トークン | 対応する `level` フィールド値 | テストレベル |
|---------------|------------------------------|-------------|
| `UNIT` | `unit` | ユニットテスト |
| `FUNC` | `functional` | 単体テスト |
| `ITA` | `integration-internal` | 内部結合テスト |
| `ITB` | `integration-external` | 外部結合テスト |
| `SYS` | `system` | システムテスト |
| `UAT` | `uat` | 受入テスト |
| `PERF` | `performance` | 性能テスト |
| `SEC` | `security` | セキュリティテスト |

- 連番は LEVEL ごとに `001` から昇順で採番する（例: `TC-FUNC-001`, `TC-FUNC-002`）
- **ID は一度発番したら改変禁止**。欠番は許容する（論理削除により自然に発生する）
- 論理削除（`deprecated: true`。`yaml-schema-cases.md` 3 章）した ID を別ケースに再利用することは禁止
- ID の LEVEL トークンと `level` フィールドは必ず上表どおり対応させる
- テストレベル自体の定義・入口/出口基準は `test-levels.md` 参照

#### run ID: `R{yyyyMMdd-HHmmss}`

- run 開始時刻によるタイムスタンプ採番（例: `R20260717-143000`）
- results_manager.py の `start-run` サブコマンドが採番する（LLM による手動採番禁止）
- 実行スキルは逐次起動が前提のため同一秒の重複開始は発生させない（採番衝突の回避）

---

## 3. 操作規約（更新主体と禁止事項）

### 3.1 test-results.yaml は results_manager.py 経由のみ

- 追記・集計・抽出・検証は、オーケストレータ `test` スキルの専用スクリプト `${CLAUDE_PLUGIN_ROOT}/skills/test/references/scripts/results/results_manager.py` に一元化する
- **LLM が test-results.yaml を Edit / Write で直接編集することを禁止**する（肥大 YAML の誤編集・集計ミスの防止）
- 実行スキル（test-run-*）は実行結果を中間データとして返却するのみとし、書き込みはオーケストレータが一元実行する（並列競合の防止）

サブコマンド概要（実装・引数の詳細はオーケストレータ `test` スキル側のドキュメントに従う）:

| サブコマンド | 機能 |
|------------|------|
| `init` | target-slug 配下の初期化 |
| `start-run` | run 開始記録（run_id 採番・scope 記録・status=in_progress） |
| `record` | ケース結果 1 件追記 + latest 更新（JSON 入力） |
| `finish-run` | run 完了記録（scope と results の突合・欠落ケース検出・status 確定） |
| `select` | 再テスト対象抽出（`retest-policy.md` のマトリクスに従い case_id リストを出力） |
| `validate` | エビデンス欠落・整合性チェック（fail の defect 3 点セット検証・annotations 構造検証）。未完了 run の未記録ケースを `resumable_runs` として JSON 出力（resume 対象の副作用なし取得） |
| `summary` | レベル別集計・推移データ出力（報告書生成用 JSON） |
| `annotate` | 所見・注記 1 件追記（トップレベル `annotations` へ append-only。実行結果 runs / results / latest には影響しない。スキーマは `yaml-schema-results.md` 7 章） |

exit code:

| exit code | 意味 |
|-----------|------|
| `0` | 正常終了 |
| `1` | 一般エラー（ファイル不在・スキーマ不整合・解析失敗等） |
| `2` | バリデーションエラー（fail の defect 3 点セット欠落等。欠落フィールドを stderr に出力） |
| `3` | ロック競合（`.lock` 残留時は実行中プロセスがないことを確認して手動削除） |
| `64` | 引数パースエラー（サブコマンド・オプションの typo・`annotate` の `--text` 空） |

### 3.2 test-cases.yaml は test-design スキルが生成・更新（例外: `review_status` と `meta.updated_at` の承認反映のみ test-review が実施）

- 構造が単純なため、設計時は test-design が直接生成してよい
- 更新時は `yaml-schema-cases.md` 3 章の revision 規則（ID 改変禁止・review_status の draft 戻し・論理削除のみ）を必ず遵守する
- 例外として、設計文脈レビューの PASS に伴う承認反映（`review_status` の `approved` 化と `meta.updated_at` の更新）のみ test-review が実施する

---

## 4. 関連 references

| 参照先 | 内容 |
|-------|------|
| `yaml-schema-cases.md` | test-cases.yaml の完全スキーマ（本ファイルからの分割先） |
| `yaml-schema-results.md` | test-results.yaml の完全スキーマ（本ファイルからの分割先） |
| `yaml-schema-analysis.md` | `analysis.yaml`（test-analyze が生成する対象理解の材料）の完全スキーマ（本ファイル 2 章の共通記述規約を継承する analysis 系スキーマ。`test-results.yaml` とは別系統で results_manager.py を経由しない） |
| `yaml-schema-environment.md` | `environment.yaml`（test-environment が生成するテスト用派生環境のマニフェスト）の完全スキーマ（本ファイル 2 章の共通記述規約を継承する environment 系スキーマ。`test-results.yaml` とは別系統で results_manager.py を経由しない） |
| `severity-policy.md` | `defect.severity` の enum 値・判定基準（唯一の SSOT） |
| `retest-policy.md` | 再テストモード・status×モード対象判定・latest 採用の集計規則 |
| `data-locations.md` | 配置パス・target-slug 解決・エビデンス移送 |
| `evidence-policy.md` | エビデンス必須要件・二段バリデーション・機微情報マスキング |
| `execution-policy.md` | 実行共通規範（条件付き動的検証・SKIPPED 記録・タイムアウト・テストデータ分離） |
| `test-levels.md` | 8 テストレベルの定義・入口/出口基準 |
| `report-format.md` | 実績 YAML から生成する報告書のフォーマット |
