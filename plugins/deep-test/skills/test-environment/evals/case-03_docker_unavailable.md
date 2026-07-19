<!-- TEST-ENVIRONMENT-EVAL-03-SENTINEL-v1 -->
# case-03 docker CLI 不在・デーモン未起動の縮退（unavailable + reason・フォールバック案内・skipped 材料）

SUT に docker 資産はあるが、docker CLI が不在またはデーモンが未起動の環境で、実行を偽装せず `applicability: unavailable` に縮退し、従来前提（ユーザー起動済み URL）へのフォールバックを案内する分岐を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target=orderapp-web project=./ base=<base> action=provision levels=functional,integration` |
| 起動形態 | 委譲（オーケストレータ `test` の Phase 1.7）/ 単独起動でも同一挙動 |
| 前提 | `project=` 配下に `docker-compose.yml`・`Dockerfile`・`.env` が存在する。`docker compose version` / `docker-compose --version` がいずれも失敗する（CLI 不在）、または `docker version` がデーモン接続エラーになる |

## 分岐の根拠

SKILL.md「責務 1」（docker 不可なら縮退）・「重要な制約」（新ゲートを追加しない）、`${CLAUDE_SKILL_DIR}/references/environment-procedures.md` 3 章（コマンド疎通の確認手順）・5 章（docker CLI 不在・デーモン未起動 → unavailable）・9 章縮退表 3 行目（従来前提へフォールバック案内・ユーザー URL なしの browser レベルは実行時 skipped）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 2 章（Docker デーモン行: 従来前提へフォールバック・URL も無ければ skipped + reason）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` 12 章（unavailable + reason・compose_command は null）。

## 期待動作

- docker 資産の検出（有無のみ）までは実施し、`derived_from` の材料を得る
- `docker compose version`（v2）→ `docker-compose --version`（v1）→ `docker version`（デーモン）の疎通確認で利用不可を実測で確認する（成功を装わない）
- 派生成果物を生成せず（生成しても検証・起動できないため）、`applicability: unavailable` + `reason`（例: 「docker CLI 不在 / デーモン未起動のため環境派生を実施できない」）・`compose_command: null` のマニフェストを出力する
- 返却に従来前提へのフォールバック案内（ユーザー起動済み URL があれば browser 系レベルは従来どおり実行可能・URL も無い場合は該当ケースが実行時 skipped〔実行手段不在〕になる旨）を含める
- 環境が使えないことを理由にフローを停止しない（新ゲートを追加しない）・SUT へ書き込まない
- 縮退判定（unavailable）の理由の妥当性も env-architect に確認させてよい（`${CLAUDE_SKILL_DIR}/references/agents.md` 4 章）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{base}/{target-slug}/environment.yaml`（`applicability: unavailable` + reason・`compose_command: null`・`derived_from` は検出結果のみ） |
| 標準出力（要約） | 環境構築結果サマリ（applicability=unavailable〔理由付き〕・フォールバック案内・ユーザー URL なし時は skipped 材料になる旨） |
| 終了状態 | 縮退マニフェスト + 理由を出力して正常終了（実行を偽装しない） |

## 関連ケース

- case-01: 資産なし（not-applicable）との使い分け（対象外 vs 手段不在）
- case-14: v1 のみ検出の警告付き best-effort（`compose_command: "docker-compose"`。試行失敗時は本ケースと同じ unavailable 扱い）
- case-05: 手段はあるが up が失敗する縮退（skipped 材料の同列ケース）
- case-06: 起動はしたが health 未達（blocked 材料との使い分け）
