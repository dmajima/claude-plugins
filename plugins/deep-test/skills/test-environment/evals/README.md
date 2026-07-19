<!-- TEST-ENVIRONMENT-EVALS-README-SENTINEL-v1 -->
# test-environment evals

本ディレクトリは `test-environment` フェーズスキル（Phase 1.7）の **AI の動作分岐検証ケース集**。
1 ケース 1 ファイルで、スキルの規範（SKILL.md / references/ / プラグイン共通 references）に基づく分岐ごとに期待動作を定義する。

## ケース一覧

| case | ファイル名 | 検証する分岐 | 起動形態 |
|------|-----------|------------|---------|
| 01 | case-01_no_assets_noop.md | docker 資産なし（compose / Dockerfile 不在）で派生せず no-op マニフェスト（not-applicable + reason）を返す非破壊分岐 | 委譲 |
| 02 | case-02_unit_only_noop.md | `levels=` が unit のみ（環境不要）で no-op（委譲前のオーケストレータ抑制と、起動された場合のスキル側自己限定） | 委譲・非対話 |
| 03 | case-03_docker_unavailable.md | docker CLI 不在・デーモン未起動での縮退（unavailable + reason・従来前提へのフォールバック案内・skipped 材料） | 委譲 |
| 04 | case-04_config_validation_failure.md | `config --quiet` 検証失敗（派生成果物は残し config_validated: false + 理由・up へ進まない・--quiet で秘匿値非展開） | 委譲 |
| 05 | case-05_up_failure.md | up 失敗（ビルド失敗・起動即死）で logs + 理由返却（対話: ユーザー URL 提示を確認・skipped 材料。非対話は case-15） | 委譲・対話 |
| 06 | case-06_health_timeout_degraded.md | health 未達（--wait-timeout 超過）で degraded + blocked 材料（対話: 維持 / down をユーザー確認。非対話は case-16） | 委譲・対話 |
| 07 | case-07_non_interactive_up_one_cycle.md | 非対話での up 許可（down までのワンサイクル完結を条件とする一時的副作用・確認なしで進行） | 委譲・非対話 |
| 08 | case-08_resume_reuse.md | resume / retest 時の再利用（ps + health 再確認で健全なら再 up 不要・不健全なら down → up） | 委譲・非対話 |
| 09 | case-09_standalone_down.md | 単独 down（コマンド起動・logs 保存 → down -v --remove-orphans → ps 残存確認。中断後の片付け） | 単独・対話 |
| 10 | case-10_provision_success.md | provision 主成功経路（資産あり → analysis 消費 → 派生生成 → config --quiet 成功 → environment.yaml 完全出力 → env-architect 自己チェック → Markdown 要約返却） | 委譲 |
| 11 | case-11_lifecycle_without_provision.md | up / down / status で environment.yaml 不在 → 推定でコマンドを組み立てず「先に provision が必要」と案内して終了 | 単独・対話 |
| 12 | case-12_production_url_suspicion_interactive.md | 本番誤爆疑義（外部 URL 突合で疑義検出）→ 差替不能・判断不能な接続をユーザーへ明示確認 | 委譲・対話 |
| 13 | case-13_production_url_suspicion_non_interactive.md | 本番誤爆疑義 × 非対話（モック / ダミー差替で続行・差替不能な疑義が残れば up へ進まない） | 委譲・非対話 |
| 14 | case-14_compose_v1_best_effort.md | compose v1 のみ検出（警告 + docker-compose 形 best-effort・compose_command 記録・試行失敗時は unavailable 扱い） | 委譲 |
| 15 | case-15_up_failure_non_interactive.md | up 失敗 × 非対話（確認なしで縮退確定・skipped 材料。case-05 の対） | 委譲・非対話 |
| 16 | case-16_health_timeout_degraded_non_interactive.md | health 未達 × 非対話（自動 down・blocked 材料・notes に degraded 由来を記録。case-06 の対） | 委譲・非対話 |
| 17 | case-17_standalone_non_interactive_multiple_slug_error.md | 単独起動 × 非対話で既存 target-slug 複数 → 自動選択せずエラー中断（target= 明示指定を案内） | 単独・非対話 |
| 18 | case-18_analysis_missing_light_supplement.md | 単独 provision で `analysis.yaml` 不在 → Read/Glob/Grep で軽量補完・`analysis_consumed: false` を記録・本番誤爆突合の材料不足は安全側（case-10 の対） | 単独・対話 |
| 19 | case-19_standalone_interactive_multiple_slug.md | 単独起動 × 対話で既存 target-slug 複数 → AskUserQuestion で既存一覧 +「新規作成」を提示して選択に従う（case-17 の対話対） | 単独・対話 |

## ケースファイルの構成

各ケースファイルは以下のセクションで構成する。

| セクション | 内容 |
|-----------|------|
| 入力 | 委譲 args または起動フレーズ / 起動形態（委譲・単独）・前提状態 |
| 分岐の根拠 | SKILL.md / references のどの規範に基づく分岐か（ファイル名・章を明記） |
| 期待動作 | 検証可能な期待動作の箇条書き（検出・生成物・実行コマンド・返却内容） |
| 期待出力 | 生成ファイル / 標準出力（要約）/ 終了状態の表（生成物と返却内容への参照でよい） |
| 関連ケース | 対になる分岐・前提となるケースへの参照 |

## 軸と不変条件について

本スキルの evals は「action 軸（provision = case-01〜04・10・12〜14・17〜19 / up = case-05〜07・15・16 / status = case-08 / down = case-09 / provision 前提を欠く lifecycle = case-11）」と「縮退軸（資産なし = case-01・環境不要 = case-02・手段不在 = case-03・v1 best-effort = case-14・検証失敗 = case-04・起動失敗 = case-05・15・health 未達 = case-06・16）」、および「対話 / 非対話」「委譲 / 単独」の分岐を検証する。
縮退軸は run 側 status との対応（skipped = 実行手段不在〔case-03・04・05・14・15〕/ blocked = 環境はあるが前提不成立〔case-06・16〕/ 影響なし〔case-01・02〕）を固定し、`execution-policy.md` の「実行を偽装しない」原則と `yaml-schema-environment.md` 12 章の縮退表に整合させる。case-07 は非対話既定値（up 許可 = ワンサイクル完結条件）を、case-08 はライフサイクルの再利用（冪等な状態確認）を、case-09 は teardown 完全性（logs → down → 残存確認）を独立に固定する。
case-10 は縮退に入らない provision 主成功経路（analysis 消費 → 派生 → config 検証 → env-architect 自己チェック → 完全マニフェスト）を、case-11 は provision 前提を欠く lifecycle の非推定終了（「先に provision が必要」の案内）を、case-12 / 13 は本番誤爆突合の対話 / 非対話対を、case-17 / 19 は単独起動の target-slug 解決の非対話 / 対話対（非対話は複数でエラー中断・対話は AskUserQuestion で既存一覧 +「新規作成」を提示して選択に従う）を、case-18 は analysis.yaml 不在時の軽量補完（`analysis_consumed: false`・本番誤爆突合の材料不足の安全側取り扱い）を固定する。対話 / 非対話の対（case-05 / 15・case-06 / 16・case-12 / 13・case-17 / 19）は独立ファイルに分割し、相互に「関連ケース」でリンクする。

どの分岐でも共通する不変条件:

- **read-only 境界**: SUT の docker 資産（compose・Dockerfile・`.env`・ソース）へ一切書き込まない。書き込み先は `environment.yaml`・`environment/` 配下・ログ保存先（`evidence/{run_id}/environment/`）のみ。`test-results.yaml` / `test-cases.yaml` / `analysis.yaml` / `fixtures.yaml` へも書き込まない
- **秘匿値の非出力**: 開発 `.env` の値を読まず複製しない（検出は有無のみ）。`.env.test` はダミー値 / credentials-manager 参照形のみ。config 検証は `--quiet` 必須。ログ保存は `evidence-policy.md` 5 章のマスキング適用
- **分離**: 派生の公開 ports は `ports: !override` による全置換 + 127.0.0.1 バインド。project 名 `{slug}-test` で名前空間分離。down は up と同一の `-f` 群 + `-p` に固定
- **新ゲートを追加しない**: ユーザー起動済み URL があれば従来前提が優先され、本スキルの不成立（no-op / 縮退）はフローを止めない
- **捏造禁止**: `applicability` / `reason` / `health` / `status.state` を実測なしに書かない（up 前の health は `unknown`・実行を偽装しない）。固定スリープで待機を偽装しない（`up --wait --wait-timeout` + 条件付き curl ポーリング）
- provision では生成後に `env-architect` を **単独起動** して自己チェックし、重大指摘を反映してから返却する（並列起動しない・エージェントに成果物を修正させない）。no-op / 縮退判定の場合も判定理由の妥当性を env-architect に確認させてよい（スキル `references/agents.md` 4 章）
