# case-01 IT-a 画面間遷移フロー pass（データ受け渡し突合）

内部結合（IT-a）のケースで、複数画面にまたがる遷移フローとモジュール間のデータ受け渡しが期待どおり成立するケース。フロー実行・登録値と参照値の突合・actual への突合結果記録を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-web / run_id=R20260717-170000 / 対象ケース TC-ITA-001（受注登録画面で登録 → 受注一覧画面で反映確認。level: integration-internal）/ 対象 URL https://localhost:5001 |
| 起動形態 | 委譲（オーケストレータ test から Skill ツール経由・MCP ゲート通過済み） |
| 前提 | MCP 利用可。連携対象モジュール（登録・一覧）が同一テスト環境に統合済み。preconditions のテストデータ準備済み |

## 分岐の根拠

SKILL.md「実行フロー」手順 3（IT-a）・「検証（チェックリスト）」（突合結果の actual 記録）、references/integration-execution.md 1.2（画面間遷移フローの確認）・1.3（データ受け渡しの突合）・5 章（エビデンス）、`${CLAUDE_PLUGIN_ROOT}/references/test-levels.md` 4.3 節（IT-a の定義・出口基準: 登録値と参照値の突合を actual に記録）。

## 期待動作

- 登録画面で入力した値（ケースの data に定義）を実施記録に残し、登録完了時点のスクリーンショットを取得 → 直後に `evidence/{run_id}/TC-ITA-001/` へ移送する
- 一覧画面へ遷移し、browser_snapshot で表示値を取得する（非同期反映は browser_wait_for で待機）
- 登録値と参照値を項目ごとに対比し、**突合結果（登録値 / 参照値の対比）を actual に記録**して pass 判定する
- 遷移のたびにスクリーンショット（`{case_id}_{NN}_{label}.png`）を取得し、ステップ直後に移送する
- postconditions（投入データの削除等）を実行する
- 中間結果 JSON（skill: "test-run-integration" / executed_by: "playwright-mcp"）を返却し、test-results.yaml への書き込みを行わない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `evidence/R20260717-170000/TC-ITA-001/` 配下に遷移ごとのスクリーンショット（`{case_id}_{NN}_{label}.png`。登録完了時点を含む）をステップ直後に移送。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-integration" / 受領 run_id / results 1 件・executed_by: "playwright-mcp"）。「引き渡し（中間結果 JSON 返却）」に準拠し、actual に登録値 / 参照値の突合結果を含める |
| 終了状態 | scope 全 1 件を 1 エントリずつ返却し、TC-ITA-001 は pass（突合一致・postconditions 実行済み） |

## 関連ケース

- case-04: データ受け渡し不一致（fail の分岐）
- case-02: IT-b の外部接続分岐
