# test-results.yaml スキーマ（yaml-schema-results）

`test-results.yaml`（実行実績）の完全スキーマを定義する SSOT である（`yaml-schema.md` からの分割ファイル）。
共通記述規約（YAML 記述規約・ID/採番規約）と操作規約（results_manager.py 経由のみ・LLM 直接編集禁止）は `yaml-schema.md` を参照。
`test-cases.yaml` 側のスキーマは `yaml-schema-cases.md` を参照。

---

## 1. meta

| フィールド | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| `target` | string | 必須 | テスト対象の名称（test-cases.yaml の `meta.target` と一致させる） |
| `schema_version` | integer | 必須 | スキーマ版数。現行 `1` |

## 2. runs[]（実行単位の記録）

| フィールド | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| `run_id` | string | 必須 | `R{yyyyMMdd-HHmmss}` 形式（`yaml-schema.md` 2.2 参照） |
| `executed_at` | string（ISO8601） | 必須 | run 開始日時 |
| `finished_at` | string（ISO8601）または null | 必須（null 許容） | run 終了日時。実行中（`in_progress`）は `null` |
| `status` | enum | 必須 | `in_progress` / `completed` / `interrupted` / `aborted`（下表） |
| `mode` | enum | 必須 | `full` / `ng-only` / `ids`（モード定義は `retest-policy.md`） |
| `scope` | list[string] | 必須 | この run の対象ケース ID リスト。`finish-run` で results と突合し中断を検知する根拠になる |
| `environment` | string | 必須 | 実行環境情報（OS・ブラウザ・対象 URL/ビルドなど） |

runs[].status の意味:

| 値 | 意味 |
|----|------|
| `in_progress` | 実行中（`start-run` 直後の初期値） |
| `completed` | scope 全ケースの結果記録が揃い正常完了 |
| `interrupted` | 中断を検知（scope に results 未記録のケースを残したまま終了。MCP ゲートによる停止を含む） |
| `aborted` | ユーザー判断等による打ち切り（再開しない） |

`in_progress` / `interrupted` の run は resume の対象になる（規約は `retest-policy.md`）。

## 3. results[]（ケース単位の結果・append-only）

| フィールド | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| `case_id` | string | 必須 | 対象ケース ID |
| `case_revision` | integer | 必須 | どの版のケースに対する結果か（監査トレーサビリティ） |
| `run_id` | string | 必須 | この結果が属する run |
| `status` | enum | 必須 | `pass` / `fail` / `blocked` / `skipped` / `na`（使い分けは 6 章） |
| `reason` | string | 条件付き必須 | `blocked` / `skipped` / `na` の場合は**必須**（判定理由） |
| `executed_by` | enum | 必須 | 実行主体。`playwright-mcp` / `test-framework` / `api` / `human-assisted` |
| `duration_sec` | number | 任意 | 実行時間（秒）。計測可能な場合は記録する |
| `actual` | string | 条件付き必須 | 実際の結果。`pass` / `fail` では必須。`blocked` / `skipped` / `na` では省略可（`reason` で代替） |
| `evidence` | list[string] | 条件付き必須 | エビデンスの相対パス（`{target-slug}/` 直下基準）。**`fail` 時は 1 件以上必須**（`execution-policy.md` 4 章。`defect.evidence` とは別の結果レベルのエビデンス）。取得・内容要件は `evidence-policy.md` 参照 |
| `defect` | map | 条件付き必須 | `status: fail` の場合は**必須**（4 章参照） |

## 4. defect サブオブジェクト（status=fail 時必須）

| フィールド | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| `severity` | enum | 必須 | `critical` / `high` / `medium` / `low`。**enum 値の意味・判定基準の SSOT は `severity-policy.md`**（本ファイルには複製しない） |
| `reproduction_steps` | list[string] | 必須 | 環境情報を含む完全な再現手順（第三者が単独で再現できる粒度） |
| `test_data` | string または map | 必須 | 欠陥を再現させる検証データ（入力値・期待値） |
| `evidence` | list[string] | 必須 | スクリーンショット・ログ・トレースの相対パス |
| `extras` | map | 任意 | テストレベル別の拡張情報（下表） |

`extras` の代表キー（レベルごとに必要なキーを snake_case で追加してよい）:

| キー | 主な利用レベル | 内容 |
|------|--------------|------|
| `measured_value` | 性能 | 実測値（応答時間など） |
| `threshold` | 性能 | 閾値（期待基準） |
| `owasp_category` | セキュリティ | 該当する OWASP カテゴリ |
| `stack_trace` | ユニット | 失敗時のスタックトレース |

```yaml
# extras の記載例（性能テスト）
extras:
  measured_value: 4.8   # 実測 4.8 秒
  threshold: 2.0        # 閾値 2.0 秒
```

- `reproduction_steps` / `test_data` / `evidence` の 3 点セットは fail 記録直後と報告書生成前の二段でバリデーションされる（規約・内容要件は `evidence-policy.md`）

## 5. latest（最新結果の集計インデックス）

| キー | 値 | 説明 |
|------|-----|------|
| `{case_id}` | map `{ status, run_id, case_revision }` | ケースごとの**最新 run 結果**への O(1) 参照インデックス |

- `latest` は results_manager.py の `record` が自動維持する集計であり、**手動編集禁止**
- 集計・報告・再テスト対象判定はすべて `latest` を採用する（規則は `retest-policy.md`）

## 6. status の使い分け（results[].status）

| status | 意味 | `reason` | `defect` | 典型例 |
|--------|------|----------|----------|--------|
| `pass` | 期待結果と一致 | 不要 | なし | — |
| `fail` | 期待結果と不一致（欠陥検出） | 不要（詳細は defect に記録） | **必須** | 期待画面に遷移しない・計算結果の誤り |
| `blocked` | 依存ケースの fail・前提不成立による**テスト論理上のブロック** | **必須** | なし | `depends_on` 先が fail / 前提データが投入不能 / ケースタイムアウトによるハング |
| `skipped` | **実行手段不在**による未実施 | **必須** | なし | Playwright MCP 未ロード / テストランナー未検出 / 負荷ツールなし |
| `na` | 対象外判定 | **必須** | なし | 対象機能が当該環境に存在しない / 要件スコープ外と判明 |

- `blocked` と `skipped` の区別が重要: `blocked` はテストの論理（依存・前提）に起因し、`skipped` は実行環境・手段に起因する
- `skipped` は環境整備後の再テスト（ng-only）対象になる（`retest-policy.md`）
- 実行手段が使えない場合に実行を偽装せず `skipped` + `reason` で記録する規範（条件付き動的検証）は `execution-policy.md` 参照

## 7. annotations[]（所見・注記。任意）

実行結果に影響しない注釈のリスト（トップレベル。`meta` / `runs` / `results` / `latest` と並列・任意）。
レビュー所見（test-review）・テスト計画由来の未確認事項などを報告書へ機械的に反映する経路であり、
**追記は results_manager.py の `annotate` サブコマンド経由のみ**（append-only。`runs` / `results` / `latest` には一切影響しない）。

| フィールド | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| `case_id` | string または null | 必須（null 許容） | 対象ケース ID。全体注記は `null`。test-cases.yaml に不在の ID は annotate が警告する（追記は許可: 柔軟性優先） |
| `run_id` | string または null | 必須（null 許容） | 対象 run。全体注記は `null` |
| `source` | string | 必須 | 注釈の出所（既定 `orchestrator`。例: `test-review/design` / `test-review/results` / `test-plan`） |
| `text` | string | 必須 | 注釈本文（空不可。`validate` が構造検証する） |

```yaml
# annotations の記載例
annotations:
- case_id: TC-FUNC-002
  run_id: R20260717-143000
  source: test-review/results
  text: 受注サマリ 0 件表示はデータ投入手順の前提にも依存するため、修正後は投入手順の再確認を推奨する
- case_id: null
  run_id: null
  source: test-plan
  text: 多重負荷試験は外部負荷ツール未検出のため計画段階から対象外（報告書の未確認事項として引き継ぐ）
```

- 報告書には「所見・注記」として転載される（Markdown: 未確認事項章内の小節 / Excel: サマリシートの表。`report-format.md`）

## 8. 記入例（結果 2 件 + latest）

```yaml
meta:
  target: sample-web-app
  schema_version: 1
runs:
  - run_id: R20260717-143000
    executed_at: "2026-07-17T14:30:00+09:00"
    finished_at: "2026-07-17T14:52:10+09:00"
    status: completed
    mode: full
    scope: [TC-FUNC-001, TC-FUNC-002]
    environment: "Windows 11 / Chromium 126 / https://localhost:5001（build 1.4.2）"
results:
  - case_id: TC-FUNC-001
    case_revision: 1
    run_id: R20260717-143000
    status: pass
    executed_by: playwright-mcp
    duration_sec: 12.4
    actual: ダッシュボード画面に遷移し、ヘッダーに user01 が表示された
    evidence:
      - evidence/R20260717-143000/TC-FUNC-001/step-04-dashboard.png
  - case_id: TC-FUNC-002
    case_revision: 2
    run_id: R20260717-143000
    status: fail
    executed_by: playwright-mcp
    duration_sec: 9.8
    actual: 受注サマリが 0 件と表示された（期待は 3 件）
    evidence:
      - evidence/R20260717-143000/TC-FUNC-002/step-02-summary-zero.png
    defect:
      severity: high                 # 判定基準は severity-policy.md
      reproduction_steps:
        - "環境: Windows 11 / Chromium 126 / https://localhost:5001（build 1.4.2）"
        - "1. 当日受注データ 3 件（ORD-001〜ORD-003）を投入する"
        - "2. user01 でログインする"
        - "3. ダッシュボード画面を開く"
        - "4. 受注サマリパネルが 0 件と表示されることを確認する"
      test_data: "当日受注データ 3 件（受注番号 ORD-001〜ORD-003）"
      evidence:
        - evidence/R20260717-143000/TC-FUNC-002/step-02-summary-zero.png
        - evidence/R20260717-143000/TC-FUNC-002/console-log.txt
latest:
  TC-FUNC-001: { status: pass, run_id: R20260717-143000, case_revision: 1 }
  TC-FUNC-002: { status: fail, run_id: R20260717-143000, case_revision: 2 }
```

## 9. 関連 references

| 参照先 | 内容 |
|-------|------|
| `yaml-schema.md` | 共通記述規約（2 章: YAML 記述規約・ID/採番規約）・操作規約（3 章: results_manager.py サブコマンド・exit code） |
| `yaml-schema-cases.md` | test-cases.yaml のスキーマ（case_id / case_revision の参照元） |
| `severity-policy.md` | `defect.severity` の enum 値・判定基準（唯一の SSOT） |
| `evidence-policy.md` | defect 3 点セットの内容要件・二段バリデーション・機微情報マスキング |
| `retest-policy.md` | latest 採用の集計規則・status×モード対象判定・resume 規約 |
| `execution-policy.md` | 条件付き動的検証（skipped 記録）・タイムアウト・中間結果返却フォーマット |
| `report-format.md` | annotations（所見・注記）・defect.extras の報告書への転載定義 |
