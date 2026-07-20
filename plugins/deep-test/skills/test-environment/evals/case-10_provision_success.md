<!-- TEST-ENV-EVAL-R2-10-SENTINEL-v1 -->
# case-10 provision 主成功経路（資産あり → analysis 消費 → 派生生成 → config 検証成功 → 自己チェック → 完全マニフェスト）

docker 資産のある SUT に対する `action=provision` の主成功経路を検証する。検出 → `analysis.yaml` 消費 → 派生生成 → `config --quiet` 成功 → environment.yaml 完全出力 → env-architect 自己チェック（重大指摘なし or 反映）→ Markdown 要約返却までを一気通貫で固定する（case-01〜04 の縮退分岐の対となる成功系）。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target=orderapp-web project=./ base=<base> action=provision levels=functional,integration` |
| 起動形態 | 委譲（オーケストレータ `test` の Phase 1.7。疑義確認が不要のため非対話でも同一挙動） |
| 前提 | `project=` 配下に `docker-compose.yml`・`Dockerfile`・`.env` が存在。`docker compose version` 成功（v2）。`analysis.yaml` 存在（build_run / external_dependencies / target_type=web-app / entry_points あり・本番誤爆疑義なし）。派生後の `config --quiet` は exit 0 |

## 分岐の根拠

SKILL.md「実行フロー」2〜8（検出 → 消費 → 要否判定 → 派生生成 → config 検証 → environment.yaml 出力 → 自己チェック）・「引き渡し」（Markdown 要約のみ）、`${CLAUDE_SKILL_DIR}/references/environment-procedures.md` 3〜7 章（検出は有無のみ・消費の対応表・派生 → `config --quiet` → 出力 → env-architect）、`${CLAUDE_SKILL_DIR}/references/compose-derivation.md` 1〜5 章（`ports: !override` + 127.0.0.1・volume 分離・`.env.test` の 2 形）、`${CLAUDE_SKILL_DIR}/references/agents.md` 3〜4 章（自己チェックは provision で必ず実施・指摘反映は本スキル）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` 2〜11 章（完全スキーマ・2.1 の YAML 記法遵守）。

## 期待動作

- 資産検出（有無のみ・`.env` の値は読まない）→ `docker compose version` で v2 疎通を確認し `compose_command: "docker compose"` を記録する
- `analysis.yaml` を Read し build_run / external_dependencies / target_type / entry_points を派生方針に消費する（`analysis_consumed: true`・対象を再解析しない）
- `environment/compose.test.yml`（`ports: !override` + 127.0.0.1 バインド・bind の `ro` 化 / named volume 再定義）と `environment/.env.test`（ダミー値 / credentials-manager 参照形のみ）を Write する（SUT 側へは書かない）
- 本番誤爆突合を実施して疑義なしを確認のうえ、コマンド規約形 + `config --quiet` の exit 0 を実測して `config_validated: true` を記録する
- `yaml-schema-environment.md` に完全準拠した environment.yaml を出力する（`applicability: applicable`・`endpoints[].health: unknown`〔up 前に healthy を捏造しない〕・`status.state: provisioned`・lifecycle はコマンド規約形の実体化・自由記述値はダブルクォート）
- env-architect を**単独起動**して自己チェックし（プロンプトに共通注入事項を含める）、重大指摘があれば本スキルが反映してから返却する（エージェントに成果物を修正させない・反映不要と判断した指摘は理由付きで所見に残す）
- SKILL.md「引き渡し」の Markdown 要約（applicability・config_validated・services / endpoints / exec_forms・env-architect 所見・次フェーズ = test-design）を返却する（up は実行しない）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `environment/compose.test.yml`・`environment/.env.test`・`{base}/{target-slug}/environment.yaml`（applicable・`analysis_consumed: true`・`config_validated: true`・`status.state: provisioned`） |
| 標準出力（要約） | 環境構築結果サマリ（派生成果物・services / endpoints / exec_forms・env-architect 自己チェック所見・test-design への引き継ぎ） |
| 終了状態 | provision 完了（起動はしない）。up は全ゲート通過後の Phase 5 手順 0 で別途実施 |

## 関連ケース

- case-01〜03: 資産なし / unit のみ / docker 不可で本経路に入らない縮退の対
- case-04: 同経路の config 検証失敗分岐（`config_validated: false` で up へ進まない）
- case-07: 本ケースの成果物を前提とする非対話 up（ワンサイクルの後段）
- case-12 / case-13: 本番誤爆疑義が検出された場合の分岐（本ケースは疑義なし）
