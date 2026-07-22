<!-- YAML-SCHEMA-ENVIRONMENT-SENTINEL-v1 -->
# environment.yaml スキーマ（yaml-schema-environment）

`environment.yaml`（test-environment が生成するテスト用派生環境のマニフェスト）の完全スキーマを定義する SSOT である（`yaml-schema.md` のスキーマ定義群ハブから参照される environment 系スキーマ）。
`environment.yaml` は test-environment（Phase 1.7）が SUT の docker 資産（compose / Dockerfile / `.env` 系）から**非破壊で派生**させたテスト用環境（`environment/compose.test.yml` / `environment/.env.test`）の内訳と、そのライフサイクル状態（provision / up / down / status）を記録する **機械可読のマニフェスト** であり、下流（test-design / browser 系実行スキル / オーケストレータ `test` / test-fixture の seed）が **単方向に消費** する。
生成主体は test-environment の LLM（Write で直接生成・更新）であり、`test-results.yaml`（results_manager.py 経由）とは別系統である。test-environment は `test-results.yaml` / `test-cases.yaml` / `analysis.yaml` / `fixtures.yaml` に一切書き込まない。
共通の YAML 記述規約（UTF-8・スペース 2・ISO8601 等）は `yaml-schema.md` 2.1 を継承する。フィールド・enum 値の追加・変更・改廃は本ファイルを起点に行い、他 references・スキルへは参照のみで内容を複製しない。

---

## 1. 位置付けと参照方向

- environment.yaml のフィールド・enum 値・スキーマ構造を定義する場所は本ファイルのみとする（唯一の SSOT）
- 下流スキルは本スキーマを **読み取り専用で消費** し、environment.yaml を書き換えない（生成・更新〔`action=up / down / status` による `status` 更新を含む〕は test-environment の専有）
- `meta.applicability`（`applicable` / `not-applicable` / `unavailable`）を **縮退動作の分岐キー** とする（12 章）。docker 資産なし・docker 利用不可の場合も推定値を捏造せず、理由を `meta.reason` に必ず記録する
- SUT 側の docker 資産（compose・Dockerfile・`.env` 等）は **read-only** である。`derived_from` には検出した有無・パスのみを記録し、内容・値（特に `.env` の実値）は読み取らず複製しない
- 秘匿値（認証情報・トークン・パスワード等）のフル値を environment.yaml にも派生成果物にも記録しない。`environment/.env.test` はダミー値または credentials-manager 参照形のみとする
- 相対パス（`derived_artifacts` 等）は `{target-slug}/` 直下を基準に記述する（`yaml-schema.md` 2.1。配置は `data-locations.md` 2 章）
- test-environment はテスト実行そのものを行わない。`endpoints[]` / `exec_forms[]` は下流への **提供形の記録** であり、実行はテスト実行スキル / オーケストレータの責務である

## 2. 代表スキーマ（全体像）

```yaml
meta:
  schema_version: 1
  target_slug: <slug>
  provisioned_at: <ISO8601>
  updated_at: <ISO8601>
  provisioner: test-environment
  analysis_consumed: true | false          # analysis.yaml を派生方針の材料にしたか
  applicability: applicable | not-applicable | unavailable   # 縮退動作の分岐キー（12 章）
  reason: <not-applicable / unavailable 時必須。それ以外 null>
  compose_command: "docker compose" | "docker-compose" | null  # v2 前提。v1 のみ検出時は警告付き記録
derived_from:                              # SUT 側の元資産（read-only。値は複製しない）
  project_root: <SUT ルートの絶対パス>
  compose_files: [ "docker-compose.yml" ]  # 検出した元 compose（-f の先頭群 = 相対パス解決の基準）
  override_files_detected: [ "compose.override.yml" ]  # 自動読込対象の検出記録（明示 -f 指定で回避）
  env_files_detected: [ ".env" ]           # 有無のみ。内容・値は読まない / 記録しない
  dockerfiles: [ "Dockerfile" ]
derived_artifacts:                         # test-environment が生成した派生成果物（deep-test データ領域）
  compose_test_file: "environment/compose.test.yml"
  env_test_file: "environment/.env.test"   # ダミー値 / credentials-manager 参照形のみ
  config_validated: true | false           # config --quiet による静的検証の結果
project:
  name: "{slug}-test"                      # -p に渡す分離名前空間（テスト用 compose プロジェクト名）
  profiles: [ ... ]                        # 有効化する profiles（モック構成等。無ければ []）
services:
  - name: web
    source: image | build                  # 既存イメージ利用か build か
    ports: [ "127.0.0.1:18080:80" ]        # 派生後の公開形（ports の !override 適用結果）
    healthcheck: declared | none           # --wait で待機可能か / curl 補助が要るか
    overrides: [ "ports を !override で 127.0.0.1 に付替", "uploads bind を ro 化" ]
endpoints:                                 # browser 系実行スキル・fixture seed への提供形
  - service: web
    base_url: "http://127.0.0.1:18080"
    purpose: browser | api
    health: unknown | healthy | unreachable
exec_forms:                                # test-run-unit 等への提供形（記録のみ。実行はしない）
  - service: app
    purpose: unit
    command_template: "docker compose -f <SUT compose> -f environment/compose.test.yml -p {slug}-test exec -T app <runner コマンド>"
    runner_hint: <pytest 等の検出ヒント | null>
lifecycle:
  up_command: "docker compose -f <SUT compose> -f environment/compose.test.yml -p {slug}-test --env-file environment/.env.test up --wait --wait-timeout 120"
  down_command: "docker compose -f <SUT compose> -f environment/compose.test.yml -p {slug}-test --env-file environment/.env.test down -v --remove-orphans"
  wait_strategy: compose-wait | http-poll | none
  wait_timeout_sec: 120
status:                                    # action=up / down / status で更新する現在状態
  state: provisioned | up | healthy | degraded | down | unknown
  last_action: provision | up | down | status
  last_action_at: <ISO8601>
  last_run_id: <run_id | null>
  notes: [ ... ]                           # 残存確認結果・警告等
```

### 2.1 YAML 記法の遵守（実体化時の必須事項）

`environment.yaml` は下流スキルが機械可読で消費する SSOT であり、代表スキーマのプレースホルダ（`<...>`）を実際の値へ実体化した結果は **必ず妥当な（parse 可能な）YAML** でなければならない（parse 不能は不許容）。

- 自由記述の文字列値（`overrides` / `notes` / `reason` / `runner_hint` 等）で、`:`（コロン）・`` ` ``（バッククォート）・`<` `>` `#` `[` `]` `{` `}` を含む、または先頭が `-` / `?` / `@` 等で始まるものは、**ダブルクォートで囲む**か `>-` / `|-` ブロックスカラーで表現する
- URL（`base_url`）・コマンド文字列（`up_command` / `down_command` / `command_template`）・ポート表記（`"127.0.0.1:18080:80"`）は `:` を含むため **必ず値全体をダブルクォート** する。未クォートのコロンは `key: ` と誤認され ScannerError を招く
- 本スキーマ内の例でコロン・バッククォートを含む値を書く場合は、次のように **クォート済みの形** で示す（誤誘導防止）:

```yaml
endpoints:
  - service: web
    base_url: "http://127.0.0.1:18080"
    purpose: browser
    health: unknown
status:
  notes:
    - "compose v1 のみ検出: `docker-compose` 形で best-effort 試行（警告）"
```

## 3. meta

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `schema_version` | integer | 必須 | スキーマ版数。現行 `1`。非互換変更時は本ファイルの改訂とセットでインクリメントする |
| `target_slug` | string | 必須 | 解決済み target-slug（解決フローは `data-locations.md`） |
| `provisioned_at` | string（ISO8601） | 必須 | 初回 provision（派生成果物の生成）の実施日時 |
| `updated_at` | string（ISO8601） | 必須 | 最終更新日時（up / down / status による `status` 更新を含む） |
| `provisioner` | string | 必須 | 生成スキル名。固定値 `test-environment` |
| `analysis_consumed` | boolean | 必須 | `analysis.yaml` を派生方針（分離対象・モック profiles・本番誤爆疑義）の材料にしたか。analysis.yaml 非存在時の軽量補完では `false` |
| `applicability` | enum `applicable` / `not-applicable` / `unavailable` | 必須 | 環境派生の適用可否。`not-applicable` = docker 資産なし等の対象外 / `unavailable` = docker 利用不可等の手段不在。縮退動作の分岐キー（12 章） |
| `reason` | string または `null` | `not-applicable` / `unavailable` 時必須 | 縮退理由。`applicable` 時は `null` |
| `compose_command` | enum `"docker compose"` / `"docker-compose"` / `null` | 必須 | 使用するコマンド形。**v2 系（`docker compose`）前提**。v1 のみ検出時は `"docker-compose"` を警告付きで記録し best-effort 試行する（12 章）。docker 利用不可時は `null` |

## 4. derived_from

SUT 側の元資産の検出記録。SUT の docker 資産は **read-only** であり、有無・パスのみを記録する（内容・値は複製しない）。

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `project_root` | string | 必須 | SUT のプロジェクトルート（docker 資産探索の起点）の絶対パス |
| `compose_files` | list[string] | 必須 | 検出した元 compose ファイル（`project_root` からの相対パス）。`-f` の先頭群として渡すファイル群であり、**派生ファイル内の相対パス解決の基準**となる |
| `override_files_detected` | list[string] | 必須（空可） | 自動読込対象（`compose.override.y*ml`）の検出記録。全ファイルを明示 `-f` で渡すことで自動読込の混入を回避する |
| `env_files_detected` | list[string] | 必須（空可） | `.env` 系ファイルの**有無のみ**。内容・値は読み取らず記録しない（唯一の例外: 本番誤爆突合のための**値を読まないキー名限定走査**。規範は `compose-derivation.md` 6 章 2） |
| `dockerfiles` | list[string] | 必須（空可） | 検出した `Dockerfile*` |

## 5. derived_artifacts

test-environment が生成した派生成果物。パスは `{target-slug}/` 直下基準の相対パスで記録する（配置は `data-locations.md` 2 章）。

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `compose_test_file` | string | 必須 | 派生 compose のパス。固定値 `environment/compose.test.yml`（ports の `!override` による全置換 + 127.0.0.1 バインド・bind mount の `ro` 化等を担う） |
| `env_test_file` | string | 必須 | テスト用 env ファイルのパス。固定値 `environment/.env.test`。**ダミー値または credentials-manager 参照形のみ**（開発 `.env` の値は読まず複製しない） |
| `config_validated` | boolean | 必須 | `config --quiet` による静的検証の結果（`-q` 必須。省略すると解決済み env 値が stdout に展開され秘匿値漏えいリスク）。`false` の場合 up へ進まない |

## 6. project

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `name` | string | 必須 | `-p` に渡すテスト用 compose プロジェクト名。規約形 `{slug}-test`（小文字英数・ダッシュ・アンダースコアのみ・先頭は小文字英数）。コンテナ・ネットワーク・named volume を開発環境から名前空間分離する |
| `profiles` | list[string] | 必須（空可） | 有効化する profiles（モック / スタブ系サービスの選択等）。無ければ `[]` |

## 7. services[]

派生後の各サービスの要約（サービス単位）。

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `name` | string | 必須 | compose サービス名 |
| `source` | enum `image` / `build` | 必須 | 既存イメージ利用か build か |
| `ports` | list[string] | 必須（空可） | 派生後の公開ポート（`"127.0.0.1:HOST:CONTAINER"` 形式）。派生 compose 側で `ports: !override` による**全置換**を適用した結果（ports は連結マージされるため、再定義のみでは開発側の公開ポートが残存する） |
| `healthcheck` | enum `declared` / `none` | 必須 | healthcheck 定義の有無。`declared` は `up --wait` で待機可能。`none` は curl 補助ポーリング（127.0.0.1 限定）の対象 |
| `overrides` | list[string] | 必須（空可） | 適用した派生内容の要約（自由記述。クォート規約は 2.1） |

## 8. endpoints[]

browser 系実行スキル・test-fixture の seed への提供形（テスト用 base URL）。

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `service` | string | 必須 | 対応するサービス名（`services[].name` を参照） |
| `base_url` | string | 必須 | テスト用 base URL。`127.0.0.1` バインドの公開ポートに対応する形（例: `"http://127.0.0.1:18080"`） |
| `purpose` | enum `browser` / `api` | 必須 | 提供先の用途（ブラウザ駆動 / API 直接検証） |
| `health` | enum `unknown` / `healthy` / `unreachable` | 必須 | 疎通確認の**最終実測値**。up 前・未確認は `unknown`（healthy を捏造しない）。down 後も最終実測値を保持するため現在疎通を意味しない（環境の現在状態は `status.state` が正） |

## 9. exec_forms[]

コンテナ内でテストランナーを実行するための実行形の**記録**（test-run-unit 等への提供形）。test-environment はこれを実行しない。

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `service` | string | 必須 | 実行先サービス名（`services[].name` を参照） |
| `purpose` | string | 必須 | 想定利用先のテストレベル（level 値。現行は `unit` を想定） |
| `command_template` | string | 必須 | コンテナ内ランナー実行形のテンプレート（10.1 の共通プレフィクス + `exec -T <service> <runner コマンド>` の形） |
| `runner_hint` | string または `null` | 必須 | 検出したランナーのヒント（`pytest` 等）。不明時は `null`（捏造しない） |

## 10. lifecycle

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `up_command` | string | 必須 | 起動コマンド（10.1 の規約形）。`up --wait --wait-timeout {N}` を用いる（`--wait` は detached モードを含意するため `-d` は書かない） |
| `down_command` | string | 必須 | 撤収コマンド（10.1 の規約形）。`down -v --remove-orphans` を用い、**up と同一の `-f` 群 + `-p` を必ず付与した形に固定**する（`-p` 単独 down のラベル解決には依存しない安全側の規約） |
| `wait_strategy` | enum `compose-wait` / `http-poll` / `none` | 必須 | 起動待機手段。`compose-wait` = `up --wait --wait-timeout`。`http-poll` = healthcheck 未定義サービスへの curl 補助ポーリング（127.0.0.1 の base URL 限定・固定スリープ禁止）。`none` = 待機なし |
| `wait_timeout_sec` | integer | 必須 | `--wait-timeout` に渡す秒数（既定 `120`） |

### 10.1 コマンド規約形

- 共通プレフィクス: `docker compose -f <SUT compose> -f <派生> -p {slug}-test --env-file <.env.test>`（`-f` は SUT の元 compose 群 → 派生 `environment/compose.test.yml` の順。compose 内の相対パスは先頭 `-f` の SUT compose 基準で解決される）
- up: 共通プレフィクス + `up --wait --wait-timeout {N}`
- down: 共通プレフィクス + `down -v --remove-orphans`。named / anonymous volume は削除されるが **external volume は削除されない**（残存する場合はその旨を `status.notes` に記録する）
- シェル環境変数は `--env-file` より**優先**される（precedence: shell > `--env-file` > `.env`）。CI 等でシェル側に同名変数が定義されている場合の汚染に注意する
- down 前のコンテナログは、run 中は `evidence/{run_id}/environment/{service}.log`、run 外の単独 down 時は `environment/logs/{timestamp}/` へ保存する（機微情報は `evidence-policy.md` のマスキング方針に従う）

## 11. status

`action=up / down / status` で test-environment が更新する現在状態。

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `state` | enum `provisioned` / `up` / `healthy` / `degraded` / `down` / `unknown` | 必須 | 現在状態。`provisioned` = 派生生成済み・未起動 / `up` = 起動済み（health 未確定）/ `healthy` = health 確認通過 / `degraded` = health 未達（`--wait-timeout` 超過等）/ `down` = 停止済み / `unknown` = 判定不能 |
| `last_action` | enum `provision` / `up` / `down` / `status` | 必須 | 最後に実施した action |
| `last_action_at` | string（ISO8601） | 必須 | 最終 action の実施日時 |
| `last_run_id` | string または `null` | 必須 | up / down 時に受領した run_id。run 外の単独操作では `null` |
| `notes` | list[string] | 必須（空可） | 残存確認結果・警告等（`ps` の残存有無・v1 best-effort・external volume 非削除 等） |

## 12. applicability による縮退

`meta.applicability` と `derived_artifacts` / `status` を分岐キーに、環境派生が成立しない場合へ縮退する。**新ゲートは追加しない**（ユーザーが起動済み URL を渡した場合は従来前提が常に優先され、本マニフェストの不成立はフローを止めない）。run 側 status の `skipped`（実行手段不在）/ `blocked`（テスト論理上の前提不成立）の意味論は `yaml-schema-results.md` / `test-levels.md` 3 章に整合させる（`execution-policy.md` の「実行を偽装しない」原則）。

| 状況 | environment.yaml の記録 | run 側 status への影響 |
|------|------------------------|----------------------|
| docker 資産なし（compose / Dockerfile 不在） | `applicability: not-applicable` + `reason`（no-op マニフェスト） | 影響なし（ユーザー起動 URL があれば従来どおり実行） |
| `levels=` が unit のみ（環境不要） | 生成しない（委譲スキップ）または `applicability: not-applicable` | 影響なし |
| docker CLI 不在・デーモン未起動 | `applicability: unavailable` + `reason` | ユーザー起動 URL なしの browser 駆動レベルは **skipped**（実行手段不在） |
| compose v1 のみ検出 | `compose_command: "docker-compose"` + `notes`（警告付き best-effort） | 試行失敗時は `unavailable` と同じ |
| `config --quiet` 検証失敗 | `config_validated: false`（派生成果物は残す。up へ進まない） | ユーザー起動 URL なしなら **skipped** 材料 |
| up 失敗（ビルド失敗・起動即死） | `status.state: down` + `notes` | **skipped**（実行手段不在） |
| health 未達（`--wait-timeout` 超過） | `status.state: degraded` + `notes`（degraded は health 判定時点の中間状態。非対話等で down を実施した後は `status.state: down` とし、notes に degraded 由来〔health 未達〕を残す） | **blocked**（環境はあるが前提不成立） |
| 中断・停止ハンドオフ（down 未実施） | `status.state: up` のまま（残存コンテナの `ps` 確認 + 手動 down 手順はハンドオフ側で案内） | resume 時に health 再確認のうえ再利用（不健全なら down → up） |

## 13. 関連 references

| 参照先 | 内容 |
|-------|------|
| `yaml-schema.md` | スキーマ定義群のハブ（本ファイルの親）。共通の YAML 記述規約・ID/採番規約 |
| `yaml-schema-analysis.md` | 材料として消費する `analysis.yaml`（`architecture.build_run` / `dependency_summary.external_dependencies` / `meta.target_type` / `entry_points`）のスキーマ |
| `data-locations.md` | 配置パス規約（`environment.yaml` / `environment/` 配下）・target-slug 解決フロー・SUT docker 資産の read-only 境界 |
| `execution-policy.md` | 実行手段不在時の skipped 記録・非対話既定値（environment up の可否・health 未達時の扱い） |
| `evidence-policy.md` | コンテナログ保存時の機微情報マスキング方針 |
| `test-levels.md` | browser 駆動レベルの入口基準と `endpoints[]` の関係・skipped / blocked の使い分け |
| `agents.md` | env-architect（派生設計の自己チェック）の起動・追加入力 |
