---
name: test-environment
description: SUT の docker 資産から非破壊で派生環境（compose.test.yml・.env.test）を生成し up/down/status と environment.yaml を管理。analysis.yaml を消費し endpoints/exec_forms を提供。責務外=テスト実行(test-run-*)・ツールチェーン検証(test-setup)・ケース設計(test-design)。test 委譲時や「テスト用コンテナ環境を作って/起動して/片付けて」と依頼時に使用。Use when provisioning deep-test's docker test env.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Write
  - AskUserQuestion
  - Bash(docker *)
  - Bash(curl *)
  - Bash(date *)
  - Agent(deep-test:env-architect)
  # Edit を持たず、Write の書込先を environment.yaml・environment/ 配下・ログ保存先に限定する運用（本 SKILL の制約+検証チェックリスト+env-architect 自己チェック）で read-only 境界を担保する
  # Bash(docker *) は docker version / docker compose（config・up・down・ps・logs・version）に、Bash(curl *) は 127.0.0.1 の疎通確認のみに用途限定する
---
<!-- TEST-ENVIRONMENT-SKILL-SENTINEL-v1 -->

# test-environment スキル

SUT の docker 資産（compose / Dockerfile / `.env` 系）から**非破壊で**テスト用派生環境（`environment/compose.test.yml` / `environment/.env.test`）を生成し、ライフサイクル（provision / up / down / status）と機械可読マニフェスト `environment.yaml` を管理する Phase 1.7 フェーズスキル。`test-analyze` の `analysis.yaml` を単方向消費し、`endpoints[]`（browser 系へのテスト用 base URL）と `exec_forms[]`（コンテナ内ランナー実行形）を下流へ提供する。**テストの実行はしない**（SUT が動く環境を用意して止まるのが境界）。

## 責務

| # | 責務 | 概要 |
|---|------|------|
| 1 | Docker 資産検出・要否判定 | `project=` 起点に compose（`compose.y*ml` / `docker-compose.y*ml` / `compose.override.y*ml`）・`Dockerfile*`・`docker/`・`.env` 系の**有無のみ**を Glob で検出し、`docker compose version` で v2 疎通を確認。資産なし / `levels=` が unit のみ / docker 不可なら no-op / 縮退 |
| 2 | analysis.yaml 消費 | `architecture.build_run`・`dependency_summary.external_dependencies`・`meta.target_type`・`entry_points` を派生方針（分離対象・モック profiles・本番誤爆疑義）の材料に単方向消費。非存在時は軽量補完（`analysis_consumed: false`） |
| 3 | 派生成果物の生成（非破壊） | `environment/compose.test.yml`（ports は `!override` で全置換 + 127.0.0.1 バインド・bind mount の `ro` 化 / named volume 再定義・モック系サービスは profiles 配下）と `environment/.env.test`（ダミー値 / credentials-manager 参照形のみ）を Write。SUT の既存 docker 資産は一切変更しない |
| 4 | 派生 config の検証 | コマンド規約形 + `config --quiet` による静的検証（解決済み env 値を stdout に展開しない）。失敗時は up へ進まず理由を返す |
| 5 | 起動（action=up） | `docker version` 疎通 → `up --wait --wait-timeout {N}` → healthcheck 未定義サービスのみ curl（127.0.0.1 限定）のポーリング補助（固定スリープ禁止）→ status 更新 |
| 6 | 実行形の提供 | `endpoints[]` と `exec_forms[]` を environment.yaml に記録し下流へ引き継ぐ（提供形の記録のみ。実行はしない） |
| 7 | teardown（action=down） | サービス別 logs 保存 → `down -v --remove-orphans`（up と同一 `-f` 群 + `-p` に固定）→ `ps` で残存確認 → status 更新 |
| 8 | environment.yaml 出力 | meta / derived_from / derived_artifacts / project / services / endpoints / exec_forms / lifecycle / status を機械可読で出力・更新。`action=status` は `ps` + health 再確認で status のみ更新 |
| 9 | 自己チェック | `env-architect` エージェントで派生設計の分離妥当性・read-only 境界・秘匿値の非出力・本番誤爆疑義・teardown 完全性・スキーマ準拠を単独レビューし、重大指摘を反映してから返却 |

## 責務外（他スキルが担当）

| 責務外 | 担当 |
|-------|------|
| テストの実行（up した環境上での実走） | `test-run-*`（実行スキル 6 種） |
| テストツールチェーンの検証（Playwright MCP・ランナー・venv） | `test-setup`（Phase 1。本スキルは SUT が動く環境を担う） |
| 対象ソースの解析（analysis.yaml 生成） | `test-analyze`（Phase 1.5。本スキルは消費のみ） |
| フィクスチャ・seed コードの生成 | `test-fixture`（Phase 1.6。seed が使うテスト用接続情報は本スキルが environment.yaml で提供） |
| ケース設計・レベル / 優先度決定 | `test-design`（Phase 2。environment.yaml を preconditions 材料に消費する側） |
| 実績記録（test-results.yaml）・`start-run --environment` の実行 | オーケストレータ `test`（本スキルは環境文字列の材料を提供） |
| 認証情報のフル値の管理・保存・取得 | `credentials-manager`（本スキルは `.env.test` に参照形を書くまで） |
| SUT イメージ・アプリの品質保証（ビルドエラーの修正等） | 対象外（up 失敗はそのまま理由として返す） |

## トリガー条件

起動する:

- オーケストレータ `test` から Skill ツール経由で委譲（フルフローの Phase 1.7 provision・全ゲート通過後の up〔Phase 5 手順 0〕・Phase 6 判定後の down）
- 「テスト用のコンテナ環境を作って」「テスト用コンテナ環境を起動して」「テスト用コンテナ環境を片付けて」「compose からテスト環境を派生して」と依頼された

起動しない:

- テストの実行・実走を求められた（`test-run-*` の責務）
- Playwright MCP 登録・ランナー検出等のツールチェーン検証を求められた（`test-setup` の責務）
- 対象アプリの一次解析（analysis.yaml 生成）を求められた（`test-analyze` の責務）
- フィクスチャ・seed コードの生成を求められた（`test-fixture` の責務）

## 前提

- `${CLAUDE_PLUGIN_ROOT}/references/` の共通規範（yaml-schema-environment.md / yaml-schema-analysis.md / data-locations.md / execution-policy.md / agents.md）が存在する
- `env-architect` エージェント定義がプラグインルート `agents/` に存在する
- `analysis.yaml`（`test-analyze` 生成）が存在すれば材料に消費。無ければ Read/Glob/Grep で軽量補完する
- compose は **v2 系（`docker compose`）前提**。v1 のみ検出時は警告付き best-effort（`compose_command: "docker-compose"` を記録）

受け取る引数:

| 引数 | 内容 | 未指定時 |
|------|------|---------|
| `target=`（別名 `target-slug=`） | 解決済み slug（委譲時にオーケストレータが付与） | 単独時は `data-locations.md` 4 章の解決フロー |
| `base=` | 基準ディレクトリ（委譲時に受領） | `data-locations.md` 1 章で解決 |
| `project=` | SUT のプロジェクトルート（docker 資産探索の起点） | カレント作業ディレクトリ |
| `action=` | `provision` / `up` / `down` / `status` | `provision` |
| `levels=` | 見込みテストレベル CSV（環境要否判定の材料。unit のみ → no-op） | environment 要と見なして判定続行 |
| `run-id=` | up / down 時に任意で受領（logs 保存先と `status.last_run_id` に使用） | run 外の単独操作として扱う |
| `--non-interactive` | 非対話モード | 対話モード |

## 実行モード判定

| 判定条件 | モード | 動作 |
|---------|-------|------|
| 引数に `--non-interactive` を含む（委譲時はオーケストレータが付与） | 非対話 | 曖昧確認せず進行。up は**許可**（down までのワンサイクル完結を条件）・health 未達は down して blocked 材料（`execution-policy.md` 9 章の既定値表）。target-slug は `data-locations.md` 4.2 章の非対話規則。本番誤爆疑義はモック / ダミー値へ差し替え、差替不能なら up へ進まない |
| 上記以外 | 対話 | 不足情報（target-slug・project）・本番誤爆疑義の扱い・health 未達 / up 失敗時の維持・down・ユーザー起動 URL 提示をユーザーに確認 |

## action 分岐

| action | フェーズ位置 | 動作概要 |
|--------|------------|---------|
| `provision`（既定） | **Phase 1.7**（test-fixture の後・test-design の前） | 検出 → analysis.yaml 消費 → 要否判定 → 派生生成 → config 検証 → environment.yaml 出力 → 自己チェック |
| `up` | 全ゲート通過後・start-run 直前（**Phase 5 手順 0**） | `docker version` 疎通 → `up --wait --wait-timeout {N}` → health 確認 → endpoints / exec_forms 確定 → status 更新 |
| `down` | **Phase 6 判定後**（PASS 時。NEEDS REVISION の ids 再実行に備え維持） | logs 保存 → `down -v --remove-orphans` → `ps` 残存確認 → status 更新 |
| `status` | 任意（resume / retest の再利用判定・単独確認） | `ps` + health 再確認で status のみ更新（健全なら再 up 不要） |

## 実行フロー

詳細手順は `${CLAUDE_SKILL_DIR}/references/environment-procedures.md`、派生パターン集は `${CLAUDE_SKILL_DIR}/references/compose-derivation.md`、エージェント運用は `${CLAUDE_SKILL_DIR}/references/agents.md` に従う。

### 1. 入力解決・action 確定
引数を解釈し `action=` / `project=` / target-slug を確定（委譲時は受領値、単独時は解決フロー）。up / down / status では既存 `environment.yaml` を Read で確認。

### 2. 資産検出・v2 疎通（provision）
`project=` 起点に docker 資産の**有無のみ**を Glob で検出し、`docker compose version` で v2 疎通を確認（内容・値は読まない）。

### 3. analysis.yaml 消費（provision）
存在時は `build_run` / `external_dependencies` / `target_type` / `entry_points` を派生方針の材料に用いる。非存在時は軽量補完（`analysis_consumed: false`）。

### 4. 要否判定（provision・no-op 分岐）
資産なし / `levels=` が unit のみ / docker 不可なら、派生せず no-op マニフェスト（`applicability` + `reason`）を出力し正常終了（縮退表は procedures 9 章）。

### 5. 派生生成（provision）
`compose-derivation.md` に従い `environment/compose.test.yml`（`ports: !override` + 127.0.0.1）と `environment/.env.test` を Write（SUT 側へは書かない）。

### 6. config 検証（provision）
コマンド規約形 + `config --quiet` で静的検証。失敗時は派生成果物を残し `config_validated: false` + 理由で返却（up へ進まない）。

### 7. environment.yaml 出力（provision）
`yaml-schema-environment.md` に完全準拠して `{base}/{target-slug}/environment.yaml` を Write（endpoints の health は `unknown`）。

### 8. 自己チェック（provision）
`env-architect` を単独起動し重大指摘を反映してから返却（評価のみ・修正は本スキル）。

### 9〜11. up / down / status のライフサイクル操作
`action=up` / `down` / `status` の手順（コマンド規約形・health 判定・logs 保存先・`ps` 残存確認・`status` 更新・resume / retest の再利用判定）は上記 action 分岐表と `${CLAUDE_SKILL_DIR}/references/environment-procedures.md` 8 章に従う。

## 検証

返却前に以下を確認する。未達成の項目は解消してから返却する。

- [ ] environment.yaml が `yaml-schema-environment.md` に準拠している（meta 必須フィールド・enum・コマンド規約形・parse 可能な YAML・自由記述値のクォート）
- [ ] SUT の docker 資産（compose・Dockerfile・`.env`・ソース）へ一切書き込んでいない（read-only 境界）
- [ ] 書き込み先が `environment.yaml`・`environment/` 配下・ログ保存先（`evidence/{run_id}/environment/`）に限定されている
- [ ] 開発 `.env` の値を読み取らず複製していない（`env_files_detected` は有無のみ・`.env.test` はダミー値 / 参照形のみ）
- [ ] config 検証を `--quiet` で行い、解決済み env 値を stdout に展開していない
- [ ] 派生後の公開 ports が `ports: !override` による全置換 + 127.0.0.1 バインドになっている（開発側 ports の連結残存がない）
- [ ] 本番誤爆疑義（`external_dependencies` と env の外部 URL 突合）を確認した（疑義はモック差替 or 明示確認）
- [ ] no-op / 縮退時は `applicability` + `reason` を捏造なく記録した（health / state を実測なしに healthy と書いていない）
- [ ] env-architect の自己チェックを実施し、重大指摘を反映した（プロンプトに共通注入事項を含めた）
- [ ] test-results.yaml / test-cases.yaml / analysis.yaml / fixtures.yaml へ書き込んでいない

## 引き渡し（オーケストレータへの返却内容）

最終応答に以下の環境構築結果サマリを含めて返却する（Markdown 要約のみ。JSON コードブロック免除・オーケストレータは environment.yaml のパス存在を確認する）。

```markdown
## 環境構築結果（test-environment）

- target-slug: <slug> / action: <provision|up|down|status> / environment.yaml: <絶対パス>
- applicability: <applicable|not-applicable|unavailable>（縮退時は reason） / analysis_consumed: <true|false> / compose_command: <docker compose|docker-compose|null>
- 派生成果物: environment/compose.test.yml・environment/.env.test / config_validated: <true|false> / project: <{slug}-test> / profiles: <[...]>
- services: <name（source / 派生後 ports / healthcheck）の一覧> / endpoints: <base_url（purpose / health）の一覧> / exec_forms: <件数（記録のみ・実行は下流）>
- status.state: <...> / 残存確認: <down 時は ps 結果・up 維持時は手動 down 手順の案内>
- env-architect 自己チェック所見: 反映済み指摘 / 反映不要と判断した指摘（理由付き）
- performance 免責: <performance レベル見込み時「コンテナ派生環境のため性能非代表」の注記材料（オーケストレータの annotate 用）>
- 次フェーズ: provision → environment.yaml を材料に test-design が環境前提を決定 / up → start-run --environment の材料・browser 系が endpoints を受領
```

## 重要な制約

- **read-only 境界**: SUT の docker 資産（compose・Dockerfile・`.env` 系）・SUT ソースへ**一切書き込まない**。Edit を持たず、Write 先を `{base}/{target-slug}/environment.yaml`・`{base}/{target-slug}/environment/` 配下・ログ保存先（`evidence/{run_id}/environment/`）に**限定**する。`test-results.yaml` / `test-cases.yaml` / `analysis.yaml` / `fixtures.yaml` へも書き込まない
- **秘匿値の非出力**: 開発 `.env` の値を**読まず複製しない**（検出は有無のみ）。`.env.test` はダミー値 / credentials-manager 参照形のみ。config 検証は `--quiet` 必須（省略すると解決済み env 値が stdout に展開され秘匿値漏えいリスク）。ログ保存時は `evidence-policy.md` 5 章のマスキング方針を適用する
- **本番誤爆の防止**: `analysis.yaml` の `external_dependencies` と env の外部 URL を突合し、本番接続の疑義はモック差替 or 明示確認とする。公開 ports は 127.0.0.1 バインドに固定する（LAN 露出防止）
- **新ゲートを追加しない**: ユーザーが起動済み URL を渡した場合は従来前提が常に優先され、本スキルの不成立（no-op / 縮退）はフローを止めない
- **実行しない・決定しない**: テスト実行は `test-run-*`、ケース設計は `test-design` の専有。`endpoints[]` / `exec_forms[]` は提供形の記録に徹する
- Bash は用途限定（docker / curl〔127.0.0.1 限定〕/ date）とし、起動待機は `up --wait --wait-timeout` + 条件付き curl ポーリングで行う（**固定スリープ禁止**）
- 他 worker スキルを呼ばない（逆呼び出し禁止）。env-architect には評価のみをさせ、成果物の修正はさせない（反映は本スキル。agents.md 冒頭の構造規範）

## 参照

| 参照先 | 内容 |
|-------|------|
| `${CLAUDE_PLUGIN_ROOT}/references/common-references.md` | プラグイン共通規範の集約インデックス（本スキルの場面別参照は 3.8 章「環境構築時」） |
| `${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` | environment.yaml の完全スキーマ SSOT（enum・`applicability` 縮退・コマンド規約形 10.1・YAML 記法遵守） |
| `${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-analysis.md` | 消費する `analysis.yaml` の完全スキーマ（build_run / external_dependencies / target_type / entry_points） |
| `${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` | environment.yaml / `environment/` 配下の配置・target-slug 解決・SUT docker 資産の read-only 注記 |
| `${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` | Docker 利用不可時の縮退（skipped）・非対話既定値（up 許可 / health 未達の扱い） |
| `${CLAUDE_PLUGIN_ROOT}/references/agents.md` | env-architect の選定・起動方式・プロンプト組み立て・共通注入事項（4.3 章） |
| `${CLAUDE_SKILL_DIR}/references/environment-procedures.md` | 検出 → 消費 → 派生 → config 検証 → up / down / status の詳細手順・縮退表・resume 再利用・ハンドオフ |
| `${CLAUDE_SKILL_DIR}/references/compose-derivation.md` | 派生パターン集（`ports: !override`・volume・profiles・`.env.test`・本番誤爆突合） |
| `${CLAUDE_SKILL_DIR}/references/agents.md` | 本スキルのフェーズ定義（env-architect の起動フェーズ） |
