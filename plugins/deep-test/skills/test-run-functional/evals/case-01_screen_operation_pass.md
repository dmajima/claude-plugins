# case-01 画面操作 pass（エビデンス収集・即時移送・照合）

オーケストレータから委譲され、MCP 利用可・対象 URL 到達可の状態で画面操作ケースが pass するケース。steps の操作対応付け・ステップごとのスクリーンショットと即時移送・expected の照合・中間結果 JSON 返却を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-web / run_id=R20260717-143000 / 対象ケース TC-FUNC-001（ログイン成功・priority: high・steps 4 手順）/ 対象 URL https://localhost:5001 |
| 起動形態 | 委譲（オーケストレータ test から Skill ツール経由・MCP ゲート通過済み） |
| 前提 | `mcp__playwright__*` ツールがロード済み。対象アプリがテスト環境で稼働中。テストユーザーが preconditions どおり準備済み |

## 分岐の根拠

SKILL.md「実行フロー」手順 3〜4・手順 7、references/functional-execution.md 1 章（基本パターン・対応表）・2 章（照合方法）・3 章（エビデンス取得・移送手順）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` 6 章（filename 指定必須）、`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 5 章（ステップ直後の移送）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 6 章（priority: high の pass エビデンス必須）。

## 期待動作

- steps の各手順を対応表に従い Playwright 操作へ対応付ける（要素操作は browser_snapshot で ref 取得 → browser_click / browser_type の基本パターン）
- 各ステップ実行後に browser_take_screenshot を **filename 指定**（`TC-FUNC-001_{NN}_{label}.png` 形式）で取得する
- スクリーンショット取得の**直後**（次ステップの前）に raw 出力先から `evidence/R20260717-143000/TC-FUNC-001/` へ move し、`{NN}_{label}.png` へ揃える（コピーではなく移動）
- expected（ダッシュボード遷移・ユーザー名表示）を browser_snapshot のアクセシビリティツリー・URL で照合し、期待値 / 実際値を対比できる形で actual に記録して pass 判定する
- 固定時間スリープを使わず、必要な待機は browser_wait_for で行う
- postconditions（ログアウト等）を実行する
- priority: high の pass ケースとしてエビデンス（主要ステップのスクリーンショット 1 件以上）を evidence に記録する
- 中間結果 JSON（skill: "test-run-functional" / 受領した run_id / executed_by: "playwright-mcp"）を返却し、test-results.yaml への書き込みを行わない
- raw 出力先（playwright/）に残骸を残さない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | ステップごとのスクリーンショットを evidence/R20260717-143000/TC-FUNC-001/{NN}_{label}.png へ即時移送（move。priority: high の pass にもエビデンス付与、raw 出力先 playwright/ に残骸なし）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-functional" / 受領 run_id / results 1 件・executed_by: playwright-mcp・期待値/実際値を対比した actual 付き）を 1 コードブロックで返却。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 1 件（TC-FUNC-001）を 1 エントリで pass 返却 |

## 関連ケース

- case-02: 表示不一致 fail（照合の不一致側の分岐）
- case-04: MCP 不可（実行手段不在の分岐）
