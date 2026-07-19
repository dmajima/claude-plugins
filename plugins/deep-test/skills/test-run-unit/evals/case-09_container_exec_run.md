<!-- TEST-RUN-UNIT-EVAL-EXEC-SENTINEL-v1 -->
# case-09 ホストにランナー不在 + environment.yaml の exec_forms あり + 環境 up → コンテナ内 exec で実行

ホストにランタイム / テストランナーが無いが、test-environment（Phase 1.7）が生成した environment.yaml の `exec_forms[]` に該当ランナーの実行形があり、環境が稼働状態（`status.state: up / healthy`）のケース。skipped に落とさず、記録値の実行形によるコンテナ内 exec 実行（代替経路）で実走することを検証する。ホスト実行（既定・優先順位 1）と、どちらの手段も無い場合の skipped（case-03）の意味論は不変であることを確認する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-web / run_id=R20260719-140000 / 対象ケース TC-UNIT-001〜002（data に pytest のテストパターン記載）/ 対象プロジェクト情報 |
| 起動形態 | 委譲（オーケストレータ test から Skill ツール経由・非対話） |
| 前提 | ホストに python / pytest が無い（unit-execution.md 1 章の検出でホスト実行不能）。`{base}/sample-web/environment.yaml` が存在し、`meta.applicability: applicable`・`exec_forms[]` に `purpose: unit`・`runner_hint: pytest` の `command_template`（lifecycle の `-f` 群 + `-p sample-web-test` を含む `docker compose ... exec -T app pytest ...` の完全形）が記録済み・`status.state: up` |

## 分岐の根拠

SKILL.md「実行モード判定」（コンテナ内 exec 実行〔代替経路〕: ホストにランナーが無く `exec_forms[]` に実行形があり環境が稼働状態なら選択できる）、SKILL.md「実行フロー」のコンテナ内 exec 実行経路、references/unit-execution.md 7 章（7.1 実行経路の優先順位・7.2 記録値をそのまま用いる・7.3 ホスト実行と同一規範）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` 9 章（exec_forms[]）・11 章（status.state）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 2 章（条件付き動的検証）。

## 期待動作

- ホストのランナー検出（unit-execution.md 1 章）で実行不能を確認したうえで、environment.yaml の `exec_forms[]`（`purpose: unit`）と `status.state: up` を確認し、コンテナ内 exec 実行を代替経路として選択する（skipped に落とさない）
- `exec_forms[].command_template` の記録値（`-f` 群 + `-p sample-web-test` を含む完全形）をそのまま用い、`-f` 群・`-p`・サービス名を自分で組み立て直さない
- 結果解釈（exit code・出力解析・ケースマッピング・タイムアウト・エビデンス保存・defect 組み立て）はホスト実行と同一規範で行う（unit-execution.md 2〜6 章）
- `executed_by: test-framework` のまま記録する（新しい enum 値を追加しない）。コンテナ内 exec である旨（用いた実行形・サービス名）を actual / reproduction_steps に記録する
- environment.yaml は読み取りのみとし、environment.yaml / SUT の docker 資産へ書き込まない。環境の up / down も行わない（test-environment の責務）
- 中間結果 JSON を返却し、test-results.yaml への書き込みを行わない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `evidence/R20260719-140000/{case_id}/` 配下にランナー実行ログ（`90_runner-log.txt` 等。unit-execution.md 5 章の命名）。environment.yaml / SUT / test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-unit" / 受領 run_id / results 2 件・executed_by: test-framework・actual にコンテナ内 exec 実行の旨）を 1 コードブロックで返却。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 2 件（TC-UNIT-001〜002）を 1 エントリずつ返却（コンテナ内 exec で実走した結果。欠落なし） |

## 関連ケース

- case-01: ホストにランナーあり（既定のホスト実行。優先順位 1 が不変であることの対比）
- case-03: ランナー不在かつ exec_forms も無い / environment.yaml 不在（どちらの手段も無い → skipped。意味論・文言不変の対比）
