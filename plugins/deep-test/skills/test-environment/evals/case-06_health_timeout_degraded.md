<!-- TEST-ENVIRONMENT-EVAL-06-SENTINEL-v1 -->
# case-06 health 未達 × 対話（--wait-timeout 超過 → degraded・blocked 材料・維持 / down をユーザー確認）

対話モードの `action=up` でコンテナは起動したが `--wait-timeout` 内に healthy へ到達しない場合に、logs を保存して `status.state: degraded` とし、**維持 / down を AskUserQuestion でユーザー確認**して選択に従う分岐を検証する。run 側へは **blocked 材料**（環境はあるが前提不成立）として渡す。非対話の自動 down 分岐は case-16 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target=orderapp-web base=<base> action=up run-id=<id>`（対話。`--non-interactive` なし） |
| 起動形態 | 委譲（オーケストレータ `test` の Phase 5 手順 0） |
| 前提 | provision 済み・`config_validated: true`。`up --wait --wait-timeout 120` がタイムアウトで非 0 終了する（コンテナは running だが healthy 未達）。healthcheck 未定義サービスは curl 補助ポーリングでも到達しない |

## 分岐の根拠

SKILL.md「責務 5」（up --wait --wait-timeout・curl 補助・固定スリープ禁止）・「実行モード判定」（対話: health 未達時の維持・down・ユーザー起動 URL 提示をユーザーに確認）、`${CLAUDE_SKILL_DIR}/references/environment-procedures.md` 8.1 章（health 確認・未達時は縮退表に従う）・9 章縮退表 7 行目（logs 保存 → 対話: 維持 / down を確認・run 側は **blocked**〔環境はあるが前提不成立。タイムアウト系の既存意味論と整合〕）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` 12 章（health 未達 = degraded + notes → blocked）。

## 期待動作

- `up --wait --wait-timeout {N}` のタイムアウトを実測で検出する（固定スリープでの待機をしない）
- healthcheck 未定義サービスには 127.0.0.1 の base URL へ curl の条件付きポーリングを試み、上限で打ち切る
- 未達サービスの logs を保存する（run_id ありのため `evidence/{run_id}/environment/`・マスキング適用）
- `status.state: degraded` + `notes`（未達サービスと経過）で environment.yaml を更新する（healthy を捏造しない）
- 「環境を維持して調査するか / down して撤収するか」を AskUserQuestion で確認し、選択に従う（維持 = degraded のまま残して手動 down 手順〔8.5 と同形〕を案内・down = 撤収して `state: down`）
- 返却に「対象レベルは **blocked** 材料（環境はあるが前提不成立）」の旨を明示する（skipped と混同しない）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | environment.yaml の `status` 更新（維持選択時 `state: degraded` / down 選択時 `state: down`・notes に未達サービス）・logs（`evidence/{run_id}/environment/{service}.log`） |
| 標準出力（要約） | 環境構築結果サマリ（health 未達の詳細・logs パス・ユーザー選択の結果・blocked 材料の旨・維持時は手動 down 手順の案内） |
| 終了状態 | ユーザー選択（維持 or down）を反映して終了。いずれも blocked 材料として返す |

## 関連ケース

- case-16: 同じ health 未達の非対話モード（自動 down・notes に degraded 由来を記録する対）
- case-05: up 自体の失敗（skipped 材料との使い分け: 手段不在 vs 前提不成立）
- case-07: health 到達して非対話ワンサイクルが完結する対
- case-09: down 単独の手順（logs 保存 → down → 残存確認）
