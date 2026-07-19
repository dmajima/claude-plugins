# フェーズ間の成果物引き継ぎ規約（state-handoff）

オーケストレータ `test` と worker スキルの間で受け渡すデータ（Skill args・返却データ・スクリプト入出力）の規約を定義する。
実行スキルからの**中間結果フォーマットは `${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 4 章が SSOT** であり、本書では構造を複製しない。

---

## 1. Skill 起動 args の共通規約

worker スキルへの引き渡しは `key=value` の空白区切り文字列で行う。値に空白を含む説明文は末尾に平文で付加してよい。

| キー | 値 | 使用フェーズ |
|------|-----|-------------|
| `target` | target-slug（解決済み） | 全フェーズ |
| `base` | 基準ディレクトリ（解決済み。例: `.claude/.local/plugins/deep-test`） | 全フェーズ |
| `spec` | 仕様書パス（仕様乖離検出の対象。指定時のみ） | Phase 1.5 |
| `diff` | 変更影響分析の対象差分（git ref / 範囲。指定時のみ） | Phase 1.5 |
| `project` | SUT のプロジェクトルート（Phase 1.6: テストコード生成先・既存 playwright.config.ts 検出の起点 / Phase 1.7: docker 資産探索の起点） | Phase 1.6 / 1.7 |
| `action` | `provision` / `up` / `down` / `status`（test-environment の動作指定。既定 provision） | Phase 1.7 / environment の up・down 呼出 |
| `context` | `design` / `results`（test-review の文脈切替） | Phase 3 / 6 |
| `run-id` | `start-run` が採番した run_id | Phase 5 / 6 / environment の up・down 呼出（任意） |
| `cases` | 対象ケース ID の CSV | Phase 3（draft 限定レビュー時）/ 5 |
| `mode` | 実行モード（再テスト時の full / ng-only / ids 等） | Phase 5 / 7 |
| `non-interactive` | `true`（非対話モード時のみ付与） | 全フェーズ |

- パスはオーケストレータが**解決済みの形**で渡す（worker スキル側で target-slug 解決をやり直させない）
- worker スキルは受け取った `base` / `target` から `{base}/{target}/...` 配下のパスを組み立てる（配置規約は `${CLAUDE_PLUGIN_ROOT}/references/data-locations.md`）
- Phase 1.6（`test-fixture`）が材料にする `analysis.yaml` は引数で渡さず、test-fixture が `{base}/{target}/analysis.yaml` を Read で解決する（非存在時は軽量補完）。成果物 `fixtures.yaml` + SUT テストコードはファイルで引き継ぐ（返却規約は 2.3）

## 2. worker スキルからの返却規約

worker スキルは最終応答に、人間可読の要約に加えて **JSON を 1 つのコードブロック**で含めて返す。オーケストレータは JSON を機械的に読み、要約はユーザー報告に使う。

### 2.1 Phase 1: test-setup → オーケストレータ

| フィールド | 型 | 内容 |
|-----------|-----|------|
| `playwright_mcp` | string | `loaded`（実利用可）/ `registered_needs_restart`（新規登録済み・要再起動）/ `unavailable`（登録失敗等） |
| `test_runner` | object / null | 検出したテストランナー（例: `{"name": "pytest", "command": "pytest"}`）。未検出は null |
| `notes` | string[] | 特記事項（既存登録の再利用・出力先の設定内容等） |

`playwright_mcp: registered_needs_restart` を受けたら、オーケストレータは再起動ハンドオフ（`${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` 3 章）を出力して停止する。

### 2.2 Phase 1.5: test-analyze → オーケストレータ

test-analyze は解析材料を**ファイルで引き継ぐ**フェーズであり、返り値の JSON コードブロックは**免除**する（本節冒頭の「JSON を 1 つのコードブロック」規約の唯一の例外）。成果物はファイル、返り値は Markdown 要約で受け渡す。

| 引き継ぎ | 形態 | 内容 |
|---------|------|------|
| 成果物 | ファイル | `{base}/{target}/analysis.yaml`（機械可読・`yaml-schema-analysis.md` 準拠）と `{base}/{target}/target-analysis.md`（人間可読）。Phase 2（test-design）が材料として消費する |
| 返り値 | Markdown 要約 | 解析結果サマリ（target-slug・対象種別・source_availability・セクション件数・source-analyst 自己チェック所見・open_questions・次フェーズ）。書式は test-analyze SKILL.md「引き渡し」節に準拠 |

- オーケストレータは成果物ファイルのパス存在のみ確認し、Markdown 要約をユーザー報告に用いる（JSON パースは行わない）。材料は Phase 2 が単方向に消費する（test-analyze へ戻さない）

### 2.3 Phase 1.6: test-fixture → オーケストレータ

test-fixture は成果物を**ファイルで引き継ぐ**フェーズであり、返り値の JSON コードブロックは**免除**する（2.2 の test-analyze と同じファイル引き継ぎ・JSON 免除の先例に倣う）。成果物はファイル、返り値は Markdown 要約で受け渡す。

| 引き継ぎ | 形態 | 内容 |
|---------|------|------|
| 成果物 | ファイル | `{base}/{target}/fixtures.yaml`（機械可読・`${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md` 1 章準拠）と SUT のテストコード（`playwright.config.ts` / フィクスチャ / setup / シード）。Phase 2（test-design）が `fixtures.yaml` を単方向消費する |
| 返り値 | Markdown 要約 | フィクスチャ基盤サマリ（target-slug・生成 / 拡充した `fixtures[].name` と type・status・SUT 書き込み先・fixture-architect 自己チェック所見・no-op 時は理由）。書式は test-fixture SKILL.md「引き渡し」節に準拠 |

- オーケストレータは成果物ファイル（`fixtures.yaml`）のパス存在のみ確認し、Markdown 要約をユーザー報告に用いる（JSON パースは行わない）。`fixtures.yaml` は Phase 2 が単方向に消費する（test-fixture へ戻さない）
- fixture 不要（no-op）時は空の `fixtures.yaml`（`fixtures: []`）+ 理由を受領し、SUT への書き込みなしで Phase 2 へ進む

### 2.4 Phase 1.7: test-environment → オーケストレータ

test-environment は成果物を**ファイルで引き継ぐ**フェーズであり、返り値の JSON コードブロックは**免除**する（2.2 / 2.3 と同じファイル引き継ぎ・JSON 免除の型）。成果物はファイル、返り値は Markdown 要約で受け渡す。up / down / status のライフサイクル呼出でも同型（`environment.yaml` の `status` 更新 + Markdown 要約）。

| 引き継ぎ | 形態 | 内容 |
|---------|------|------|
| 成果物 | ファイル | `{base}/{target}/environment.yaml`（機械可読・`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` 準拠）と派生成果物（`{base}/{target}/environment/compose.test.yml`・`environment/.env.test`）。Phase 2（test-design）が preconditions / 環境前提の材料に、Phase 5（オーケストレータ）が `start-run --environment` の環境文字列の材料に単方向消費する |
| 返り値 | Markdown 要約 | 環境構築結果サマリ（target-slug・action・applicability・派生成果物・config_validated・project 名・endpoints・status.state・env-architect 自己チェック所見・縮退時は reason）。書式は test-environment SKILL.md「引き渡し」節に準拠 |

- オーケストレータは成果物ファイル（`environment.yaml`）のパス存在のみ確認し、Markdown 要約をユーザー報告に用いる（JSON パースは行わない）。`environment.yaml` は下流が単方向に消費する（test-environment へ戻さない）
- no-op / 縮退（docker 資産なし・unit のみ・docker 利用不可）時は `applicability: not-applicable | unavailable` + `reason` を受領し、フローを止めずに Phase 2 へ進む（ユーザー起動 URL があれば従来前提が優先）

### 2.5 Phase 2: test-design → オーケストレータ

| フィールド | 型 | 内容 |
|-----------|-----|------|
| `plan_path` | string | `{base}/{target}/test-plan.md` |
| `cases_path` | string | `{base}/{target}/test-cases.yaml` |
| `case_count` | integer | 生成・更新したケース総数（deprecated 除く） |
| `levels` | string[] | 採用したテストレベル（`test-levels.md` の level 値） |
| `updated_case_ids` | string[] | 今回新規作成・revision 更新したケース ID（差し戻し修正時は修正対象のみ） |

### 2.6 Phase 3 / 6: test-review → オーケストレータ

| フィールド | 型 | 内容 |
|-----------|-----|------|
| `context` | string | `design` / `results` |
| `verdict` | string | `PASS` / `NEEDS_REVISION`（欠落時は NEEDS_REVISION として扱う。flow.md 3 章） |
| `findings` | object[] | 指摘リスト。各要素: `{target_case_id, content, basis, severity(欠陥関連のみ), confidence, recommendation}` |
| `approved_case_ids` | string[] | （設計文脈のみ）PASS 判定に含まれるケース ID（test-review が approved 化を実施した対象） |
| `unverified` | string[] | 未確認事項（入力不足・環境制約で評価できなかった項目） |

- NEEDS_REVISION の場合、オーケストレータは `findings` を**要約せずそのまま** test-design（設計文脈）へ、または flow.md 4.2 の遡行方法（結果文脈）へ引き渡す

### 2.7 Phase 5: test-run-* → オーケストレータ（中間結果）

**`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 4 章の中間結果返却フォーマットに従う**（本書では複製しない）。要点のみ:

- ラッパー `{skill, run_id, results: []}` の `results[]` 要素を、オーケストレータが `record` の入力として **1 件ずつ**渡す（`record` は単一要素、または要素 1 件のラッパーを受理する）
- `run_id` はオーケストレータが引き渡した値をそのまま返させる（実行スキルは採番しない）
- scope 全ケースについて 1 エントリ必須（実行不能でも skipped / blocked + reason で返す）

### 2.8 Phase 7: test-report → オーケストレータ

| フィールド | 型 | 内容 |
|-----------|-----|------|
| `report_path` | string | 生成した報告書のパス（セッション作業領域直下） |
| `format` | string | `excel` / `markdown` |
| `masked` | boolean | 機微情報マスキングを適用したか |
| `notes` | string[] | 免責注記・ng-only 注記等、報告書に含めた注意事項の要約 |

## 3. results_manager.py の入出力（オーケストレータ ⇔ スクリプト）

スクリプトの stdout はすべて機械可読な JSON。人間向け情報は stderr（`[INFO]` / `[WARN]`）に出る。

| サブコマンド | stdin / 入力 | stdout | 主要フィールド |
|------------|-------------|--------|---------------|
| `init` | — | JSON | `ok` / `created` / `target_dir` / `results_file` / `evidence_dir` |
| `start-run` | — | **JSON** | `run_id` / `mode` / `scope_size` / `active_runs_warning`。`run_id` を JSON 抽出（例: `json.load(sys.stdin)['run_id']`）して Phase 5 全体で使う（flow.md 6 章 Phase 5） |
| `record` | `--result-json <path\|->`（`-` は stdin） | JSON | `ok` / `case_id` / `status` / `latest_updated` / `recorded` / `scope_size` / `remaining`（未記録ケース） |
| `finish-run` | — | JSON | `ok` / `status`（確定した run status）/ `missing`（欠落ケース一覧）/ `recorded` / `scope_size` |
| `select` | — | JSON | `cases`（approved・レベル順）/ `draft_cases`（承認済みケースゲート対象）/ `excluded_deprecated` / `unknown_ids` / `warnings` / `details`（ケース別: level・title・priority・automation・timeout_sec・latest_status 等） |
| `validate` | — | JSON | `ok` / `violations`（`{type, run_id, case_id, detail}`）/ `warnings` / `resumable_runs`（`{run_id, status, missing}`。未完了 run の未記録ケース） |
| `summary` | — | JSON | `levels`（レベル別: total・pass・fail・blocked・skipped・na・not_run）/ `totals` / `runs`（推移: run 別 counts）/ `latest_fails`（severity 付き）/ `warnings` |

exit code の意味（0 / 1 / 2 / 3）とバリデーション時の stderr 出力は SKILL.md「results_manager.py」の表を参照。

### オーケストレータ側の利用対応表

| オーケストレータの判断 | 使用する出力 |
|----------------------|-------------|
| 承認済みケースゲート | `select` の `draft_cases` |
| 人間承認ゲートの提示項目 | `select` の `cases` 件数 + `details`（level 内訳・timeout_sec 合計・破壊的操作の有無はケース定義の steps / preconditions から判断） |
| MCP ゲートの要否 | `select` の `details[].level`（unit のみなら判定不要） |
| 一次バリデーション（fail 3 点セット） | `record` の exit code 2 + stderr の欠落フィールド |
| 中断検知・resume の残ケース | `summary` の `runs[].status`（中断 run の抽出）/ `validate` の `resumable_runs`（未記録ケースの特定。flow.md 5 章） |
| 最終バリデーション | `validate` の `ok` / `violations` |
| 引き渡し・報告の集計 | `summary` の `levels` / `totals` / `runs` / `latest_fails` |

## 4. 引き継ぎで守ること

- オーケストレータは worker スキルの生の全文出力を保持し続けない（JSON + 要約を取り込んだら破棄してよい）
- `findings`（レビュー指摘）だけは例外として、差し戻し時に**そのまま**引き渡す（flow.md 4 章）
- パス・ID（target-slug / run_id / case_id）は必ず解決済み・採番済みの実値で受け渡す（プレースホルダのまま渡さない）
- 受け渡しデータに認証情報等の機微情報を平文で含めない（マスク規約は `${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 5 章）
