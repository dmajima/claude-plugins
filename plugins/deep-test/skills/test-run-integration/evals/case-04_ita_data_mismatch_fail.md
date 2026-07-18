# case-04 IT-a データ受け渡し不一致 fail

内部結合（IT-a）のケースで、登録側モジュールで入力した値が参照側モジュールで異なって表示されるケース。突合による fail 判定と、登録値・参照値の対比を含む defect 3 点セットの収集を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-web / run_id=R20260717-183000 / 対象ケース TC-ITA-002（顧客登録画面で入力した顧客名が顧客詳細画面に正しく表示されることの検証）/ 対象 URL https://localhost:5001 |
| 起動形態 | 委譲（オーケストレータ test から Skill ツール経由・MCP ゲート通過済み） |
| 前提 | MCP 利用可・モジュール統合済み。登録した顧客名の一部（例: 全角スペース以降）が詳細画面で欠落して表示される欠陥がある状態 |

## 分岐の根拠

SKILL.md「実行フロー」手順 3（IT-a: 突合結果を actual に記録）・手順 5（fail 時）、references/integration-execution.md 1.3（データ受け渡しの突合: 不一致は登録側・参照側両方の証跡）・7 章（defect の組み立て: test_data に登録値・期待値・実際値）、`${CLAUDE_PLUGIN_ROOT}/references/test-levels.md` 4.3 節（IT-a の確認観点: モジュール間のデータ整合）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 1 章（3 点セット）。

## 期待動作

- 登録画面で入力した値（登録値）を実施記録に残し、登録完了時点のスクリーンショットを取得・移送する
- 詳細画面へ遷移して browser_snapshot で表示値（参照値）を取得し、項目ごとに突合して不一致を検出、fail と判定する
- actual に突合結果（登録値 / 参照値の対比・不一致箇所）を記録する
- defect 3 点セットをその場で収集する:
  - reproduction_steps: 環境情報を先頭に、登録から参照までの複数画面にまたがる操作列全体（入力値含む）
  - test_data: 入力値（登録値）・期待値（詳細画面での期待表示）・実際値（実表示）を項目ごとに明記
  - evidence: **登録側・参照側両方のスクリーンショット**の相対パス
- defect.severity を severity-policy.md の判定フローで付与する（迷ったら高い側に倒す）
- postconditions（作成した顧客データの削除）を fail 時も実行し、失敗した場合は隠蔽せず記録する

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `evidence/R20260717-183000/TC-ITA-002/` 配下に登録側・参照側両方のスクリーンショット（fail のため defect 3 点セットの evidence として参照される）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-integration" / 受領 run_id / results 1 件・defect 3 点セット付き）。「引き渡し（中間結果 JSON 返却）」に準拠し、postconditions の実行結果（失敗時は隠蔽せず記録）を含める |
| 終了状態 | scope 全 1 件を 1 エントリずつ返却し、TC-ITA-002 は fail（actual に登録値 / 参照値の突合不一致を記録、severity 付与） |

## 関連ケース

- case-01: データ受け渡し一致（pass の分岐）
- case-03: IT-b の fail（API 証跡あり）
