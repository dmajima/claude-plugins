<!-- TEST-ENV-EVAL-R2-16-SENTINEL-v1 -->
# case-16 health 未達 × 非対話（自動 down・blocked 材料・notes に degraded 由来を記録。case-06 の対）

非対話モードの `action=up` でコンテナは起動したが `--wait-timeout` 内に healthy へ到達しない場合に、ユーザー確認なしで**自動 down** し（環境を維持したまま放置しない）、対象レベルの **blocked 材料**として理由を返す分岐を検証する。対話で維持 / down を確認する分岐は case-06 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target=orderapp-web base=<base> action=up run-id=R20260719-160000 --non-interactive` |
| 起動形態 | 委譲（オーケストレータ `test` の Phase 5 手順 0・非対話） |
| 前提 | provision 済み・`config_validated: true`。`up --wait --wait-timeout 120` がタイムアウトで非 0 終了する（コンテナは running だが healthy 未達）。healthcheck 未定義サービスは curl 補助ポーリングでも到達しない |

## 分岐の根拠

SKILL.md「実行モード判定」（非対話: health 未達は down して blocked 材料〔`execution-policy.md` 9 章の既定値表〕）、`${CLAUDE_SKILL_DIR}/references/environment-procedures.md` 8.1 章（health 確認・未達時は縮退表に従う）・9 章縮退表 7 行目（非対話: down して理由返却・run 側は **blocked**）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 9 章（health 未達 = down して対象レベルの blocked 材料として記録・環境を維持したまま放置しない）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` 12 章（health 未達 = degraded + notes → blocked）。

## 期待動作

- `up --wait --wait-timeout {N}` のタイムアウトを実測で検出する（固定スリープで待機しない・curl 補助ポーリングは上限で打ち切る）
- 未達サービスの logs を保存する（`evidence/{run_id}/environment/`・マスキング適用）
- **AskUserQuestion を行わず自動 down する**（維持 / down の確認は対話の case-06 のみ。環境を維持したまま放置しない）
- down 後の environment.yaml は `status.state: down` に更新しつつ、`notes` に **health 未達（degraded）由来の down** であること・未達サービスと経過を記録する（up 自体の失敗〔skipped 系〕と判別できる形で残す）
- healthy を捏造しない（実測で到達していない endpoints を healthy と書かない）
- 返却に「対象レベルは **blocked** 材料（環境はあるが前提不成立）」の旨を明示する（skipped と混同しない）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | environment.yaml の `status` 更新（自動 down 後の `state: down`・notes に degraded 由来・未達サービス）・logs（`evidence/{run_id}/environment/{service}.log`） |
| 標準出力（要約） | 環境構築結果サマリ（health 未達の詳細・自動 down 実施済み・blocked 材料の旨・logs パス） |
| 終了状態 | 確認なしで down 完了・blocked 材料 + 理由を返して終了（維持したまま放置しない） |

## 関連ケース

- case-06: 同じ health 未達の対話モード（維持 / down をユーザー確認する対）
- case-15: up 失敗 × 非対話（skipped 材料との使い分け: 手段不在 vs 前提不成立）
- case-09: down 手順の単独系（logs 保存 → down → 残存確認の共通形）
