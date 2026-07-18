# case-03 対象 URL 不達（タイムアウト超過）→ blocked

対象 URL への遷移が応答を返さないままケースタイムアウトを超過するケース。blocked + reason（経過時間・最後に完了したステップ）の記録と、接続不能が即時判明する場合（skipped）との使い分けを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-web / run_id=R20260717-150000 / 対象ケース TC-FUNC-003（timeout_sec: 120）/ 対象 URL https://localhost:5001 |
| 起動形態 | 委譲（オーケストレータ test から Skill ツール経由・MCP ゲート通過済み） |
| 前提 | MCP 利用可。対象アプリがハング状態で、browser_navigate が応答を返さないままケースタイムアウト（120 秒）を超過する |

## 分岐の根拠

SKILL.md「実行フロー」手順 3・手順 6、references/functional-execution.md 5 章（status 判定の分岐: 応答なしタイムアウト → blocked / 接続不能の即時判明 → skipped）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 8 章（タイムアウト超過は blocked + reason）・2 章（対象 URL 到達不可 = 実行手段不在 → skipped）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（blocked / skipped の意味論）。

## 期待動作

- browser_navigate が応答なしのままケースタイムアウト（120 秒）を超過した時点で実行を打ち切り、当該ケースを **blocked** と判定する
- reason にタイムアウト発生の旨・経過時間・最後に完了したステップを記録する
- blocked に defect・severity を付与しない（severity は fail のみ）
- 接続拒否・名前解決不能などで**接続不能が即時判明**した場合は blocked ではなく **skipped**（実行手段不在）とする使い分けを行う（functional-execution.md 5 章の分岐表に従い、実際に発生した事象に対応する status を選ぶ）
- 待機可能な範囲のリトライで無限に待ち続けない（タイムアウト制御を優先する）
- scope に他ケースが残っていれば次ケースへ進み、scope 全件について 1 エントリずつ返却する
- 実行できなかった操作を実行済みとして報告しない（偽装禁止）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（初手の browser_navigate が応答なしのまま打ち切るため、移送対象のスクリーンショット等は発生しない）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-functional" / 受領 run_id / results 1 件。blocked エントリは reason に経過時間・最後に完了したステップを記載し defect・severity なし）。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 1 件（TC-FUNC-003）を 1 エントリで blocked 返却（接続不能が即時判明した場合は skipped と使い分け。実行済みへの偽装なし） |

## 関連ケース

- case-04: MCP 不可（skipped の分岐・実行手段不在）
- case-01: 対象到達可（正常系）
