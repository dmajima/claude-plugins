<!-- R13-EVAL-SCEN-13-SENTINEL-v1 -->
# case-13 manual-assist ケース × 対話で「後で実施」選択（オンデマンド手順書生成 → skipped + reason にパス転記）

`automation: manual-assist` の system / uat スコープのケースについて、対話の結果聴取でユーザーが**「後で実施」**を選択した場合に、オンデマンド手順書生成（オーケストレータの責務）へ縮退し、`status: skipped` + reason に**手順書パスを転記**して記録することを検証する（本ケースは**「後で実施」選択専用**。blocked 選択の分岐は test-run-functional evals case-13 が専用で扱う）。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260719-120000` / ケース: `[TC-UAT-005]`（`automation: manual-assist`。帳票の印字イメージ・画面レイアウトの妥当性など人手の目視確認が不可欠な受入ケース）/ アプリ情報: `https://localhost:5001` |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・対話） |
| 前提 | 対話モードのため args に `manual-sheet=` は付与されていない（一括生成は非対話時のみ）。結果聴取でユーザーが**「後で実施」**を選択する |

## 分岐の根拠

SKILL.md「実行モード判定」の manual-assist 分岐（対話時は `${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` に従いユーザーに確認を依頼する）、`${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` 3 章（結果聴取の選択肢 **後で実施** = 手順書を生成し skipped で記録・後日 ng-only 再テスト対象）・5 章（「後で実施」を選択 → その場で手順書生成へ縮退〔7 章と同型のオンデマンド生成〕→ skipped + reason〔手順書パス〕で記録・skipped = 人間の応答可能性の不在の意味論）・7 章（スクリプト起動主体は**オーケストレータのみ**・実行スキルは起動せずパスを reason に転記するだけ・フェイルオープン）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 9 章（生成失敗時は従来どおり理由のみで skipped）。

## 期待動作

- 提示 3 要素（確認対象・手順・判断基準）を提示のうえ結果を聴取し、ユーザーが**「後で実施」**を選択したらオンデマンド手順書生成へ縮退する
- 実行スキル自身は `generate_manual_sheet.py` を**起動しない**（生成はオーケストレータの責務。オーケストレータが非対話一括生成と同型のオンデマンド生成〔`--ids` に当該ケースのみ指定〕を行う）
- 生成された手順書パスを `status: skipped` + reason に**転記**して記録する（例: 「後で実施が選択されたため未実施。手順書: manual/manual-sheet_20260719-120400.md」）
- 手順書生成に失敗した場合（フェイルオープン）は、従来どおり理由のみ（例: 「後で実施が選択されたため未実施」）の skipped で返す（フローを止めない。manual-execution.md 7 章）
- skipped は「実行手段不在 = 人間の応答可能性の不在」の意味論とし、blocked（テスト論理起因）と混同しない。当該ケースは後日 ng-only 再テストの対象となる（manual-execution.md 5 章）
- 実行を偽装しない（executed_by を `playwright-mcp` と誤記しない・skipped を「問題なし」に書き換えない）。未実施の uat ケースを「受入完了」と結論しない
- scope 全件について 1 エントリを返す
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `manual/manual-sheet_20260719-120400.md`（TC-UAT-005 の手順書節。オーケストレータによるオンデマンド生成。実行スキルは生成しない）。エビデンスなし・test-results.yaml へも書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-scenario" / 受領 run_id / results 1 件が skipped + reason〔手順書パス入り。生成失敗時は理由のみ〕・executed_by: human-assisted） |
| 終了状態 | skipped + reason で返却（人員の都合がつき次第、手順書を用いた実施と ng-only 再テストが可能） |

## 関連ケース

- case-07: manual-assist × 対話の主系（pass / fail 聴取の基本形。「後で実施」選択の分岐が本ケース）
- case-08: manual-assist × 非対話（オーケストレータ一括生成の `manual-sheet=` 受領 → reason 転記。縮退機構が同型）
- case-14: exploratory のセッション開始聴取における「後で実施」（チャーターシート様式の同型縮退）
- test-run-functional evals case-13: manual-assist × blocked 選択（前提不成立側の専用ケース）
