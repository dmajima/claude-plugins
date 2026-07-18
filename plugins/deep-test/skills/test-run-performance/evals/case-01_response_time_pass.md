# case-01 応答時間 pass（3 回計測中央値）

主要画面の表示応答時間を計測し、3 回計測の中央値が閾値内で pass となるケース。複数回計測・中央値採用・pass 記録を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-143000` / ケース: `[TC-PERF-001]`（expected: ダッシュボード表示 3 秒以内）/ アプリ情報: `https://localhost:5001` |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ） |
| 前提 | Playwright MCP ロード済み / 対象機能は機能レベルで安定動作 / 計測条件が preconditions で宣言済み |

## 分岐の根拠

SKILL.md「実行フロー」（単一セッション応答時間・3 回計測・中央値・閾値判定）、`references/performance-execution.md` 1 章（メトリクス取得コード）・2 章（複数回計測と中央値）・3.1（pass / fail 判定）、`${CLAUDE_PLUGIN_ROOT}/references/test-levels.md` 4.7（性能テストの主な確認観点）。

## 期待動作

- `browser_navigate` の所要時間と `browser_evaluate` による Performance API メトリクス（TTFB・DOMContentLoaded・load・LCP）を取得する（performance-execution.md 1.1）
- 同一計測を既定 3 回繰り返し、主指標の**中央値**を実測値として採用する（performance-execution.md 2 章）
- 中央値 ≦ 閾値（3 秒）のため `status: pass` とし、`actual` に実測値（中央値）・閾値・計測回数を記述する（performance-execution.md 3.1）
- 計測値の生データ（各回の値・中央値・平均・最小/最大・閾値・判定）を JSON で evidence/ に保存し move する（performance-execution.md 5 章 / data-locations.md 5 章）
- 単位を実測値と閾値で揃えて比較する（ms/秒の換算。performance-execution.md 1.1）
- 中間結果 JSON に `status: pass` / `executed_by: playwright-mcp` / `evidence` を埋めて返却する（execution-policy.md 4 章）
- `test-results.yaml` を直接編集しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 計測値生データ(JSON: 各回の値・中央値・平均・最小/最大・閾値・判定)・スクリーンショットを evidence/{run_id}/{case_id}/ へ移送。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-performance" / 受領 run_id / 当該ケース pass・executed_by: playwright-mcp・evidence 付き） |
| 終了状態 | 3 回計測の中央値が閾値（3 秒）内のため当該ケースを pass で返却 |

## 関連ケース

- case-02: 閾値超過で fail（対の分岐）
