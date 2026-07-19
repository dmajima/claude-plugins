<!-- TEST-ENV-EVAL-R2-11-SENTINEL-v1 -->
# case-11 environment.yaml 不在での up / down / status（推定でコマンドを組み立てず「先に provision が必要」と案内）

provision 未実施の対象へ `action=up`（down / status も同型）が要求された場合に、既存 `environment.yaml` の非存在を確認し、**推定で `-f` 群・`-p`・`--env-file` を組み立てて docker コマンドを実行しない**まま「先に provision が必要」と案内して終了する分岐を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | `/deep-test:test-environment action=up target=orderapp-web`（または「テスト用コンテナ環境を起動して」。down / status でも同一挙動） |
| 起動形態 | 単独（コマンド → スキル。対話） |
| 前提 | `{base}/{target-slug}/environment.yaml` が存在しない（provision 未実施。`environment/` 配下の派生成果物もない） |

## 分岐の根拠

SKILL.md「実行フロー」1（up / down / status では既存 environment.yaml を Read で確認する）、`${CLAUDE_SKILL_DIR}/references/environment-procedures.md` 2 章（up / down / status では既存 `{base}/{target-slug}/environment.yaml` を Read で確認し、非存在なら「先に provision が必要」と案内して終了する〔推定でコマンドを組み立てない〕）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` 1 章（lifecycle のコマンド規約形は environment.yaml が保持する。生成・更新は test-environment の専有）。

## 期待動作

- 既存 `{base}/{target-slug}/environment.yaml` を Read で確認し、非存在を確定する
- `lifecycle.up_command` / `down_command` に相当するコマンドを**推定で組み立てない**（SUT の compose を勝手に探索して `-f` 群・`-p`・`--env-file` を仮定した up / down / ps を実行しない）
- `action=up` の要求を暗黙に provision へ切り替えない（派生生成・environment.yaml の生成を勝手に行わない）
- 「先に provision が必要」の案内と、provision の起動例（`action=provision` の委譲 args / コマンド形）を返して終了する
- SUT・deep-test データ領域のいずれへも書き込まない（docker の起動系・撤収系コマンドを一切実行しない）
- down / status が要求された場合も同一の判定・案内で終了する

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（environment.yaml を生成しない・SUT へ書き込まない） |
| 標準出力（要約） | environment.yaml 非存在の旨・「先に provision が必要」の案内・provision の起動例 |
| 終了状態 | docker コマンド未実行のまま案内して終了（非破壊。実行を偽装しない） |

## 関連ケース

- case-10: 前提となる provision 主成功経路（本ケースの案内先）
- case-08 / case-09: environment.yaml が存在する場合の status / down（lifecycle を Read で取得する正常系）
