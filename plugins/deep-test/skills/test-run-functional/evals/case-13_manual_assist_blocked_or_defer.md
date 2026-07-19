<!-- R13-EVAL-FUNC-13-SENTINEL-v1 -->
# case-13 manual-assist ケース × 対話で blocked 選択（前提不成立の理由を聴取して blocked + reason 記録）

`automation: manual-assist` の functional スコープのケースについて、対話の結果聴取でユーザーが **blocked**（前提不成立で確認不能）を選択した場合に、理由を聴取して `status: blocked` + reason・`executed_by: human-assisted` で記録することを検証する（本ケースは **blocked 選択専用**。「後で実施」選択のオンデマンド手順書縮退は test-run-scenario evals case-13 が専用で扱う）。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=sample-web` / `run_id=R20260719-113000` / ケース: `[TC-FUNC-010]`（`automation: manual-assist`。人の目視でのみ判定できる表示品質確認）/ 対象 URL |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・対話） |
| 前提 | 対話モード。結果聴取でユーザーが **blocked** を選択し、理由（例: 表示品質確認に必要な一覧テストデータが未投入で `preconditions` を満たせない）を申告する |

## 分岐の根拠

SKILL.md「実行モード判定」の manual-assist / exploratory 分岐（対話時は `${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` に従いユーザーに確認を依頼し `executed_by: human-assisted` で記録）、`${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` 2 章（提示 3 要素: `preconditions` の充足状態を含む）・3 章（結果聴取の選択肢 **blocked** = 前提不成立で確認不能。理由を伺う）・5 章（手動ケースの `blocked` はテスト論理起因に限る既存意味論の維持）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（blocked = 前提不成立等のテスト論理上のブロック / skipped = 実行手段不在の使い分け）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 4 章（executed_by の enum）。

## 期待動作

- 提示 3 要素（確認対象・手順・判断基準）を提示のうえ結果を聴取し、ユーザーが **blocked** を選択したら続けて理由を伺い、`status: blocked` + reason（申告された前提不成立の内容）を `executed_by: human-assisted` で記録する
- blocked はテスト論理起因（前提不成立で確認不能）に限る。人間の応答可能性の不在を blocked に記録しない（skipped との使い分け。manual-execution.md 5 章 / yaml-schema-results.md 6 章）
- 人間の申告を脚色・補完しない（聴取していない理由・状況をでっち上げない・blocked を pass / fail / skipped に書き換えない）
- 「後で実施」が選択された場合の縮退（オンデマンド手順書生成 → skipped + reason に手順書パス転記）は本ケースの対象外（test-run-scenario evals case-13 が専用で扱う）
- scope 全件について 1 エントリを返す
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（確認不能のためエビデンスなし。test-results.yaml へも書き込まない） |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-functional" / 受領 run_id / results 1 件が blocked + reason〔前提不成立の申告内容〕・executed_by: human-assisted） |
| 終了状態 | blocked を記録して返却（前提の整備後、ng-only 再テストの対象になる。retest-policy.md） |

## 関連ケース

- case-07: manual-assist × 対話の主系（pass / fail 聴取の基本形。blocked 選択の分岐が本ケース）
- case-14: 同じ聴取で pass 申告 + エビデンス未提供（pass 終端側の分岐）
- case-03: 対象 URL 不達による blocked（自動実行側のテスト論理起因 blocked との対比）
- test-run-scenario evals case-13: manual-assist ×「後で実施」選択（オンデマンド手順書生成 → skipped + パス転記の専用ケース）
