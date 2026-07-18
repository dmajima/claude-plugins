# case-02 表示不一致 fail（3 点セット収集）

expected の表示内容と実際の画面が一致しないケース。fail 判定と、失敗時点スクリーンショット + コンソールログ + 実施した操作列から組み立てた再現手順（defect 3 点セット）のその場収集を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-web / run_id=R20260717-143000 / 対象ケース TC-FUNC-002（必須項目未入力時のバリデーションエラー表示確認）/ 対象 URL https://localhost:5001 |
| 起動形態 | 委譲（オーケストレータ test から Skill ツール経由・MCP ゲート通過済み） |
| 前提 | MCP 利用可・対象アプリ稼働中。全項目未入力で登録ボタンを押すとエラー表示されず登録が完了してしまう（欠陥がある）状態 |

## 分岐の根拠

SKILL.md「実行フロー」手順 5・「検証（チェックリスト）」、references/functional-execution.md 2 章（照合方法: 待機を 1 回試してから判定）・4 章（失敗時の追加収集）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 1 章（fail 時の必須 3 点セット）、`${CLAUDE_PLUGIN_ROOT}/references/severity-policy.md`（判定フロー）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 7 章（失敗検出時の追加収集: snapshot + コンソールログ）。

## 期待動作

- expected（バリデーションエラー表示・登録拒否）と実際（エラーなしで登録完了）の不一致を browser_snapshot で確認し、fail と判定する（判定前に browser_wait_for での待機を 1 回試し、描画途中の誤判定を防ぐ）
- fail 確定直後（次ケースに進む前）に以下をその場で収集する:
  - 失敗時点のスクリーンショット（`{case_id}_{NN}_fail.png` 等）→ 直後に evidence へ移送
  - browser_snapshot の結果をテキスト保存（`91_snapshot.txt`）
  - browser_console_messages の結果をテキスト保存（`90_console-log.txt`）
- `reproduction_steps` は環境情報（OS・ブラウザ・対象 URL・ビルド情報）を先頭に、**実際に実施した操作列**（入力値含む）を番号付きで再構成し、発生条件（毎回再現か）を付す
- `test_data` に入力値・期待値・実際値の 3 つを明記する
- `defect.evidence` に失敗時点のスクリーンショットとコンソールログの相対パス（実在するファイル）を含める
- `defect.severity` を severity-policy.md の判定フローで付与する（迷ったら高い側に倒す）
- actual に「期待値 / 実際値」を対比できる形で実際の結果を記録する
- fail を pass や skipped に書き換えない・隠蔽しない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 失敗時点スクリーンショット・90_console-log.txt・91_snapshot.txt を evidence/R20260717-143000/TC-FUNC-002/ へ即時移送・保存（defect 3 点セットの evidence として実在パスを記録）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-functional" / 受領 run_id / results 1 件。fail エントリは reproduction_steps・test_data・evidence の 3 点セットと severity 付き defect、期待値/実際値対比の actual を含む）。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 1 件（TC-FUNC-002）を 1 エントリで fail 返却（pass / skipped への書き換え・隠蔽なし） |

## 関連ケース

- case-01: 照合一致（pass の分岐）
- case-05: 依存先 fail による後続 blocked（fail の波及）
