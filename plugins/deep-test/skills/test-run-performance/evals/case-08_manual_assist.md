# case-08 manual-assist ケース × 対話モード（人手確認して human-assisted 記録）

`automation: manual-assist` の performance スコープのケースについて、対話時はユーザーに手動確認を依頼し、報告された実測値と結果を `executed_by: human-assisted` で記録することを検証する。非対話モードで skipped + reason になる分岐は case-09 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-172000` / ケース: `[TC-PERF-012]`（`automation: manual-assist`。外部監視ダッシュボードの目視読み取り・実運用相当環境での体感応答性確認など、Playwright 計測で代替できない人手確認ケース）/ アプリ情報: `https://localhost:5001` |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・対話） |
| 前提 | 対話モード（非対話モードで skipped + reason になる分岐は case-09） |

## 分岐の根拠

SKILL.md「実行モード判定」の manual-assist 分岐（対話時は `${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` に従いユーザーに手動確認を依頼し `executed_by: human-assisted` で記録・非対話時は skipped + reason）、`${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` 2 章（提示 3 要素: performance では確認対象・計測方法・ケースの閾値）・3 章（結果聴取の選択肢と AskUserQuestion 設計）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 9 章（非対話既定値表: manual-assist は実行せず skipped + reason 記録）・4 章（executed_by の enum）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` 2 章（automation→executed_by 対応: manual-assist → human-assisted）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（skipped の意味論）。

## 期待動作

- **対話時（主系）**: ユーザーに手動確認（確認対象・計測方法・ケースの閾値）を依頼し、報告された結果（実測値と pass / fail）を受けて `executed_by: human-assisted` で記録する。fail 時は defect 3 点セットを収集する
- Playwright タイミング計測で自動実行したかのように偽装しない（executed_by を `playwright-mcp` と誤記しない・実測値をでっち上げない）
- 人手確認で得た実測値も閾値との照合結果とあわせて `actual` に記録する（ユーザー報告値であることが判別できる形で記す）
- **非対話時（対比）**: 人手介在ができないため skipped + reason で返す（詳細は case-09。execution-policy.md 9 章）
- scope 全件について 1 エントリを返す
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 人手確認時: 取得できた確認記録（ユーザー提供の計測画面キャプチャ等があれば evidence/ へ）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-performance" / 受領 run_id / results 1 件・executed_by: human-assisted） |
| 終了状態 | 人手確認結果を記録して返却（非対話 skipped は case-09） |

## 関連ケース

- case-09: 同じ manual-assist ケースの非対話モード（skipped + reason で返す分岐）
- case-01: Playwright 計測で自動実行される pass ケース（executed_by: playwright-mcp）との対比
- case-03: 負荷ツール未検出による skipped（実行手段不在の別要因）との対比
- case-05: MCP 未ロードによる skipped（実行手段不在のさらに別の要因）との対比
