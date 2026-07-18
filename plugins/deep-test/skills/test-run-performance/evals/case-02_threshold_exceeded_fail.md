# case-02 閾値超過 fail（measured_value / threshold 記録）

主要画面の応答時間が閾値を超過し fail となるケース。閾値超過の判定・extras への実測値/閾値記録・超過率バンドによる severity 判定を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-143000` / ケース: `[TC-PERF-002]`（expected: 検索結果表示 2 秒以内）/ アプリ情報: `https://localhost:5001` |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ） |
| 前提 | Playwright MCP ロード済み / 計測の結果、中央値が 4.8 秒（閾値 2.0 秒の 2.4 倍） |

## 分岐の根拠

`references/performance-execution.md` 3.1（fail 判定）・3.2（超過率算出）、`${CLAUDE_PLUGIN_ROOT}/references/severity-policy.md` 4.1（閾値超過率バンド: 実測値が閾値の 2 倍以上 → high）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 4 章（defect.extras の measured_value / threshold）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 1 章（fail 時 defect 3 点セット）。

## 期待動作

- 3 回計測の中央値（4.8 秒）が閾値（2.0 秒）を超過するため `status: fail` とする（performance-execution.md 3.1）
- `defect.extras.measured_value: 4.8`（単位明記）/ `defect.extras.threshold: 2.0` を記録する（yaml-schema-results.md 4 章）
- 超過率 =（4.8 − 2.0）÷ 2.0 = 1.4（140%）で、実測値が閾値の 2 倍以上のため severity を `high` と判定する（severity-policy.md 4.1）。SSOT の基準に照らして判定し、本ファイルにバンドを複製しない
- defect 3 点セット（reproduction_steps〔環境・計測条件含む〕/ test_data〔計測対象・入力〕/ evidence〔計測値生データ・スクリーンショット〕）を収集する（evidence-policy.md 1 章）
- 業務重要度に応じて 1 段階補正を行った場合は理由を defect に記録する（severity-policy.md 4.1）
- 中間結果 JSON に fail エントリを埋めて返却する（execution-policy.md 4 章）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 計測値生データ(JSON)・スクリーンショットを evidence/{run_id}/{case_id}/ へ移送。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-performance" / 受領 run_id / 当該ケース fail・extras.measured_value/threshold・severity 付き） |
| 終了状態 | 中央値が閾値超過のため当該ケースを fail で返却 |

## 関連ケース

- case-01: 閾値内 pass（対の分岐）
- case-03: 負荷ツール未検出（skipped）
