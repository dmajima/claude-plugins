<!-- TEST-RUN-SCN-EVAL-TIMEBOX-SENTINEL-v1 -->
# case-16 exploratory ケース × タイムボックス満了で正常終了 → 結果判定（blocked を適用しない）

`automation: exploratory` の uat スコープのケースについて、セッションが**タイムボックス（timeout_sec）満了**に達した場合に、blocked を適用せず**正常終了**として終了聴取・結果判定へ進むことを検証する。タイムアウト = blocked を適用する通常ケース（自動実行系）との規約差、およびセッション開始不能（前提不成立）による blocked（case-14）との使い分けを明確にする。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260719-140000` / ケース: `[TC-UAT-006]`（`automation: exploratory`。case-11 と同一のチャーターケース・`timeout_sec: 1800` = タイムボックス 30 分）/ アプリ情報: `https://localhost:5001` |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・対話） |
| 前提 | 対話モード。セッションは正常に開始・進行し、探索が完了しないままタイムボックス（30 分）に到達する（対象は稼働しており開始不能ではない = case-14 の主分岐とは別事象） |

## 分岐の根拠

SKILL.md「実行モード判定」の manual-assist / exploratory 分岐（対話時は `${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` に従う）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 8 章（`automation: exploratory` の例外: `timeout_sec` はタイムボックスであり、**超過 = blocked を適用しない**。自動実行系のケースタイムアウトが blocked になる規約〔case-04 等〕との差）、`${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` 6.2（タイムボックス満了 = セッションの正常終了。開始不能〔前提不成立〕の blocked とは別事象）・6.3〜6.5（終了聴取・セッションシート・発見事象の記録）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 4 章（非 fail セッションの発見は results[] 直下の `extras.session_findings`・fail は `defect.extras.session_findings`）・6 章（blocked の意味論）。

## 期待動作

- **タイムボックス満了の扱い（主系）**: セッションがタイムボックス（30 分）に達した時点で探索を打ち切り、**blocked にしない**。満了を正常終了として終了聴取（セッションノート・発見事象・PROOF 振り返り）へ進む（execution-policy.md 8 章 / manual-execution.md 6.2）
- **結果判定**: 終了聴取の結果で総合結果を確定する。重大な発見がなければ `status: pass`、欠陥発見があれば `status: fail`（最重要 1 件を defect 3 点セット + `defect.extras.session_findings`）。defect 化しない軽微な発見は results[] 直下の `extras.session_findings` に記録する（yaml-schema-results.md 4 章）
- **タイムボックス実績の記録**: セッションシートの「タイムボックス実績」に満了で終了した旨を記す（時間切れを欠陥や異常として記録しない）。`duration_sec` にはタイムボックス実績を記録してよいが、満了それ自体を fail/blocked の根拠にしない
- **使い分けの厳守**: タイムボックス満了（正常終了）を case-14 の「セッション開始不能（blocked）」や自動実行系のタイムアウト（blocked）と混同しない
- `executed_by: human-assisted` で記録する。人間の申告を脚色・補完しない（時間内に確認できなかった範囲を「確認済み」と書かない・未確認は未確認事項として残す）
- scope 全件について 1 エントリを返す
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `evidence/R20260719-140000/TC-UAT-006/session-sheet.md`（タイムボックス実績 = 満了で終了を明記）+ 補助取得物。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-scenario" / 受領 run_id / results 1 件・executed_by: human-assisted・総合結果〔pass/fail〕・非 fail なら results[] 直下 `extras.session_findings`・fail なら defect + `defect.extras.session_findings`。満了を blocked にしない） |
| 終了状態 | タイムボックス満了を正常終了として結果を記録して返却（時間切れを blocked/fail の根拠にしない） |

## 関連ケース

- case-11: 同じ exploratory ケースの対話主系（時間内に探索完了して pass 終端。本ケースは満了で打ち切る側）
- case-14: セッション**開始不能**による blocked（前提不成立のテスト論理起因。満了の正常終了とは別事象の対比）
- case-17: セッション開始後の**探索続行不能**による blocked（本ケースの満了正常終了とは異なり、満了前に探索前提が崩れる分岐）
- test-run-functional evals case-12: exploratory の fail 終端（発見事象の defect 化）との対比
