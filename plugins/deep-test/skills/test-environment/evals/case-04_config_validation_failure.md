<!-- TEST-ENVIRONMENT-EVAL-04-SENTINEL-v1 -->
# case-04 config 検証失敗（config_validated: false・成果物は残す・up へ進まない・--quiet で秘匿値非展開）

派生生成までは成功したが `config --quiet` の静的検証が失敗した場合に、派生成果物を**残したまま** `config_validated: false` + 失敗理由を記録し、**up へ進まない**分岐を検証する。検証時に解決済み env 値を stdout に展開しない（`--quiet` 必須）ことも固定する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target=orderapp-web project=./ base=<base> action=provision levels=functional` |
| 起動形態 | 委譲（オーケストレータ `test` の Phase 1.7） |
| 前提 | docker 資産あり・v2 疎通 OK・`analysis.yaml` 存在。派生生成後の `config --quiet` が非 0 で失敗する（例: 実環境の compose が `!override` タグを受理しない・未定義変数・構文エラー） |

## 分岐の根拠

SKILL.md「責務 4」（config --quiet 静的検証・失敗時は up へ進まず理由を返す）・「検証」チェック（--quiet で解決済み env 値を展開していない）、`${CLAUDE_SKILL_DIR}/references/environment-procedures.md` 6 章（コマンド規約形での検証・失敗時は成果物を残し config_validated: false・`!override` の受理可否もここで検出）・9 章縮退表 5 行目（ユーザー URL なしなら skipped 材料）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` 5 章（config_validated が false の場合 up へ進まない）・12 章（縮退表の同行）。

## 期待動作

- 検出 → 消費 → 派生生成（`environment/compose.test.yml` / `.env.test`）までを実施する
- コマンド規約形（`docker compose -f <SUT compose> -f environment/compose.test.yml -p {slug}-test --env-file environment/.env.test config --quiet`）で検証し、exit code の失敗を実測で確認する
- `--quiet` を付与して実行する（省略して解決済み env 値・秘匿値を stdout に展開しない）
- 派生成果物を**削除せず残し**、`derived_artifacts.config_validated: false` + 失敗理由（stderr の要点）を environment.yaml と返却に記録する
- **up へ進まない**（action=up が後続で要求されても config_validated: false のままなら再検証を先行させる）
- 修正の当たり（`!override` 非受理なら compose 版数の案内・未定義変数なら `.env.test` への変数追加）を返却に含めるが、SUT 側の修正はしない
- 縮退判定（config_validated: false）の理由も env-architect に確認させてよい（`${CLAUDE_SKILL_DIR}/references/agents.md` 4 章。provision の自己チェック自体は省略しない）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `environment/compose.test.yml`・`environment/.env.test`（残置）・`{base}/{target-slug}/environment.yaml`（`config_validated: false` + reason 記録・`status.state: provisioned` のまま） |
| 標準出力（要約） | 環境構築結果サマリ（config 検証失敗の理由・成果物残置の旨・up 不可・ユーザー URL なしなら skipped 材料・修正の当たり） |
| 終了状態 | up へ進まず失敗理由を返して終了（実行を偽装しない・秘匿値を展開しない） |

## 関連ケース

- case-05: config は通ったが up が失敗する後続段の縮退
- case-03: そもそも docker 手段が使えない縮退（検証以前の段）
- case-07: config 検証成功から非対話 up まで進む対
