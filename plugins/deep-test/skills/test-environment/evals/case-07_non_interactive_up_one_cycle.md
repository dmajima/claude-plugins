<!-- TEST-ENVIRONMENT-EVAL-07-SENTINEL-v1 -->
# case-07 非対話での up 許可（down までのワンサイクル完結を条件とする一時的副作用）

非対話モードで `action=up` が確認なしで**許可**される分岐を検証する。up は「down までのワンサイクル完結」を条件とする一時的副作用として整理され（test-setup の「永続的副作用を作らない」原則とは区別）、health 到達 → endpoints / exec_forms 確定 → status 更新まで自動進行する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target=orderapp-web base=<base> action=up run-id=R20260719-140000 --non-interactive` |
| 起動形態 | 委譲（オーケストレータ `test` の Phase 5 手順 0。全ゲート通過後・start-run 直前） |
| 前提 | provision 済み（`config_validated: true`・endpoints の health は `unknown`）。docker デーモン疎通 OK。`up --wait --wait-timeout 120` が成功し全サービス healthy 到達 |

## 分岐の根拠

SKILL.md「実行モード判定」（非対話: up は許可〔down までのワンサイクル完結を条件〕）・「action 分岐」（up = 全ゲート通過後・start-run 直前 = Phase 5 手順 0）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 9 章非対話既定値表（environment up = 許可・ワンサイクル完結条件・永続的副作用は作らない）、`${CLAUDE_SKILL_DIR}/references/environment-procedures.md` 8.1 章（up 手順）・9 章縮退表 8 行目（非対話モード = up を許可）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` 10 章（lifecycle のコマンド規約形）・11 章（status の更新）。

## 期待動作

- 非対話でも up の実施可否を AskUserQuestion で確認**しない**（既定値表に従い自動進行する）
- `docker version` 疎通 → `lifecycle.up_command`（コマンド規約形: up と同一 `-f` 群 + `-p {slug}-test` + `--env-file`）を実行する
- `--wait` は detached を含意するため `-d` を付けない。healthcheck 未定義サービスのみ curl（127.0.0.1）で補助確認する（固定スリープ禁止）
- health 到達を実測してから `status.state: healthy`・`endpoints[].health: healthy` に更新する（実測前に healthy と書かない）
- `exec_forms[]` の command_template / runner_hint を確定し、`status`（`last_action: up` / `last_run_id`）を更新する
- 返却に `start-run --environment` の材料（project 名・base URL）と、run 完了後は Phase 6 判定を経て down でワンサイクルを完結する旨を含める（up したまま放置しない前提の明示）
- performance レベルが scope に見込まれる場合は免責注記材料（コンテナ派生環境・性能非代表）を返却に含める

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | environment.yaml の `status` 更新（`state: healthy`・`endpoints[].health: healthy`・`last_action: up`・`last_run_id`） |
| 標準出力（要約） | 環境構築結果サマリ（up 成功・endpoints / exec_forms・start-run --environment 材料・down までのワンサイクル完結の旨・免責注記材料〔該当時〕） |
| 終了状態 | 確認なしで up 完了・healthy 確定。テスト実行（test-run-*）はしないで返却 |

## 関連ケース

- case-05 / case-06: up 失敗・health 未達の縮退（本ケースは成功系）
- case-02: unit のみで up 自体が不要となる対
- case-09: ワンサイクルの完結側（down）の手順
