# case-04 進行状況付き中断（長大シナリオ）

複数の長大シナリオを含む scope の実行中に、あるケースがタイムアウトし以降のケースに到達できず中断するケース。ケース単位の結果確定・進行状況の actual 記録・scope 全件返却を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-160000` / ケース: `[TC-SYS-010, TC-SYS-011, TC-SYS-012]`（各 20〜30 ステップの長大シナリオ）/ アプリ情報: `https://localhost:5001` |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ） |
| 前提 | Playwright MCP ロード済み / TC-SYS-011 のステップ 12 で応答が返らずケースタイムアウト（既定 120 秒）に達する |

## 分岐の根拠

`references/scenario-execution.md` 5 章（長大シナリオの中断耐性）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 8 章（タイムアウト時の blocked 記録）・3 章（scope 全件返却）、`${CLAUDE_PLUGIN_ROOT}/references/retest-policy.md` 6 章（resume 判定の材料）。

## 期待動作

- TC-SYS-010 は完了しているため、その結果エントリを確定して失わない（ケース単位の結果確定。scenario-execution.md 5 章）
- TC-SYS-011 はタイムアウトのため `status: blocked` + `reason`（タイムアウト発生・到達ステップ〔例: ステップ 12 まで到達〕・経過時間）で記録する（execution-policy.md 8 章）
- `actual` に進行状況（どのステップまで到達したか）を残す（scenario-execution.md 5 章）
- TC-SYS-012 に到達できない場合も、`status: blocked`（前提未到達）または `skipped`（実行手段喪失）+ reason で**エントリを返す**。scope 全 3 件のエントリを返却する（execution-policy.md 3 章）
- 未到達を「pass」「問題なし」と書き換えない（execution-policy.md 2 章 未実施を問題なしと書かない）
- オーケストレータが resume を判断できるよう、各ケースの到達状況を返却データに含める（retest-policy.md 6 章）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 実行済み範囲（TC-SYS-010 全ステップ・TC-SYS-011 の到達ステップまで）のスクリーンショットを `evidence/R20260717-160000/{case_id}/` 配下へ移送。未到達の TC-SYS-012 はなし。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-scenario" / 受領 run_id / results 3 件）。「引き渡し（中間結果 JSON 返却）」に準拠し、特記事項として各ケースの到達状況（resume 判断材料）を含める |
| 終了状態 | scope 全 3 件を 1 エントリずつ返却。実行済みの TC-SYS-010 は結果を確定して保持、TC-SYS-011 は blocked + reason（タイムアウト・到達ステップ・経過時間）、未到達の TC-SYS-012 は blocked または skipped + reason（pass へ書き換えない） |

## 関連ケース

- case-01: 全ステップ完了の正常シナリオ
- case-05: MCP 未ロードによる skipped（実行手段不在との対比）
