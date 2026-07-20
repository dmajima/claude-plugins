<!-- TEST-RUN-UNIT-EVAL-ENVDOWN-SENTINEL-v1 -->
# case-10 ホストにランナー不在 + exec_forms あり + 環境 down → 代替経路を選択せず skipped（環境を起動しない）

ホストにランタイム / テストランナーが無く、environment.yaml の `exec_forms[]` に該当ランナーの実行形はあるが、環境が未起動（`status.state: down`）のケース。コンテナ内 exec 実行（代替経路）の成立条件（`status.state: up / healthy`）を満たさないため代替経路を選択せず、**環境の up も自分で行わず**、従来どおり skipped + reason で返すことを検証する。稼働時に実走する分岐は case-09 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-web / run_id=R20260719-150000 / 対象ケース TC-UNIT-001〜002（data に pytest のテストパターン記載）/ 対象プロジェクト情報 |
| 起動形態 | 委譲（オーケストレータ test から Skill ツール経由・非対話） |
| 前提 | ホストに python / pytest が無い（unit-execution.md 1 章の検出でホスト実行不能）。`{base}/sample-web/environment.yaml` が存在し、`meta.applicability: applicable`・`exec_forms[]` に `purpose: unit`・`runner_hint: pytest` の実行形が記録済み。ただし `status.state: down`（down 実行後・未起動） |

## 分岐の根拠

SKILL.md「実行モード判定」（コンテナ内 exec 実行〔代替経路〕は環境が稼働状態〔`status.state: up / healthy`〕の場合に限り選択できる）、references/unit-execution.md 7.1（実行経路の優先順位: 優先 2 の成立条件に稼働状態を含む・「環境が未起動〔`status.state: provisioned / down / unknown`〕の場合は本経路を選択しない。up は test-environment / オーケストレータの責務。本スキルは環境を起動しない」・優先 3 = どちらの手段も無い → 従来どおり skipped + reason〔1.4 の判定・意味論・文言のまま〕）・1.4（検出不能時の判定: 実行を偽装せず実際の原因を reason に記載）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` 11 章（status.state の enum）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（skipped = 実行手段不在の意味論）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 2 章（条件付き動的検証）。

## 期待動作

- ホストのランナー検出（unit-execution.md 1 章）で実行不能を確認したうえで、environment.yaml の `exec_forms[]` と `status.state` を確認し、`down` のため代替経路を**選択しない**（unit-execution.md 7.1）
- **環境の up を自分で行わない**（`docker compose up` 等を実行しない。up は test-environment / オーケストレータの責務。本スキルは環境を起動しない）
- 優先順位 3（どちらの手段も無い）に該当し、scope 全件を skipped + reason で返す。reason には実際の原因を記載する（例: 「pytest ホスト実行不能（コマンド不在）・コンテナ内 exec 代替経路は環境未起動（status.state: down）のため不成立」。実行を偽装しない）
- `status.state: degraded`（環境はあるが health 未達）の blocked とは判定を混同しない（down = 経路不成立の skipped / degraded で前提不成立 = テスト論理起因の blocked。unit-execution.md 7.1 / yaml-schema-results.md 6 章）
- environment.yaml は読み取りのみとし、environment.yaml / SUT の docker 資産へ書き込まない
- 中間結果 JSON を返却し、test-results.yaml への書き込みを行わない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（実行しないためランナーログも生成しない）。environment.yaml / SUT / test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-unit" / 受領 run_id / results 2 件・全件 status: skipped + reason）を 1 コードブロックで返却。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 2 件（TC-UNIT-001〜002）を skipped で 1 エントリずつ返却（欠落なし）。環境は down のまま（起動していない） |

## 関連ケース

- case-09: 同じ構成で環境が稼働状態（`status.state: up`）→ コンテナ内 exec で実走する対
- case-03: ランナー不在かつ environment.yaml も無い（経路自体が存在しない skipped。reason 文言の従来意味論）
- case-04: blocked（テスト論理起因）と skipped（実行手段不在）の使い分けの対比
