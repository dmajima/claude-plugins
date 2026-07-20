# case-07 manual-assist ケース × 対話モード（人手確認して human-assisted 記録）

`automation: manual-assist` の functional スコープのケースについて、対話時はブラウザ操作で補助しつつ最終判定をユーザーに手動確認依頼し、結果を `executed_by: human-assisted` で記録することを検証する。非対話モードで skipped + reason になる分岐は case-08 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=sample-web` / `run_id=R20260717-163000` / ケース: `[TC-FUNC-010]`（`automation: manual-assist`。人の目視でのみ判定できる表示品質確認）/ 対象 URL |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・対話） |
| 前提 | 対話モード（非対話モードで skipped + reason になる分岐は case-08）。Playwright MCP はロード済み |

## 分岐の根拠

SKILL.md「実行モード判定」（`automation: manual-assist` のケース: 対話時は `${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` に従いユーザーに手動確認を依頼し `executed_by: human-assisted` で記録・非対話時は skipped + reason）、`${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` 2 章（提示 3 要素: 確認対象・手順・判断基準）・3 章（結果聴取の選択肢と AskUserQuestion 設計）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 9 章（非対話既定値表: manual-assist は実行せず skipped + reason）・4 章（executed_by の enum）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` 2 章（automation→executed_by 対応: manual-assist → human-assisted）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（skipped の意味論）。

## 期待動作

- **対話時（主系）**: ブラウザ操作で確認可能な部分は補助的に提示しつつ、最終判定はユーザーに手動確認（確認対象・手順・判断基準を提示のうえ）を依頼し、結果（pass / fail）を受けて `executed_by: human-assisted` で記録する。fail 時は defect 3 点セットを収集する
- Playwright で自動判定したかのように偽装しない（executed_by を `playwright-mcp` と誤記しない・結果を捏造しない）
- **非対話時（対比）**: 人手介在ができないため skipped + reason で返す（詳細は case-08。execution-policy.md 9 章）
- scope 全件について 1 エントリを返す
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 人手確認時: 補助スクリーンショット等（取得した場合は evidence/{run_id}/{case_id}/ へ移送）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-functional" / 受領 run_id / results 1 件・executed_by: human-assisted） |
| 終了状態 | 人手確認結果を記録して返却（非対話 skipped は case-08） |

## 関連ケース

- case-08: 同じ manual-assist ケースの非対話モード（skipped + reason で返す分岐）
- case-01: Playwright で自動実行される pass ケース（executed_by: playwright-mcp）との対比
- case-04: MCP 未ロードによる skipped（実行手段不在の別要因）との対比
- case-13: 同じ聴取で blocked（前提不成立で確認不能）を選択した分岐
- case-14: 同じ聴取で pass 申告 + エビデンス未提供の分岐（actual への申告明記）
