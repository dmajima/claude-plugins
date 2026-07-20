<!-- R13-EVAL-FUNC-12-SENTINEL-v1 -->
# case-12 exploratory ケース × 対話モード（発見事象 2 件の defect 化 + session_findings + 再現ケース起票推奨）

`automation: exploratory` の functional スコープのケースについて、探索セッションで**発見事象が複数（2 件）出た**場合に、最重要の 1 件を代表 defect（3 点セット）として記録し、全発見を `defect.extras.session_findings` とセッションシートに残し、発見ごとの再現ケース draft 起票を推奨案内することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=sample-web` / `run_id=R20260719-110000` / ケース: `[TC-FUNC-022]`（`automation: exploratory`。title「検索・一覧画面まわりの探索セッション（入力揺らぎと表示崩れ）」・steps = 探索指針・`timeout_sec: 1800` = タイムボックス 30 分）/ 対象 URL |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・対話） |
| 前提 | セッション終了聴取で発見事象 2 件が申告される: (1) 検索キーワードに全角スペースのみを入力すると 0 件表示ではなくエラー画面になる（重大）(2) 一覧の備考列で長文が折り返されず表が崩れる（軽微）。総合結果は fail |

## 分岐の根拠

SKILL.md「実行モード判定」の manual-assist / exploratory 分岐（対話時は `${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` に従いユーザーに確認を依頼し `executed_by: human-assisted` で記録）、`${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` 6.5（発見事象の記録: 代表 defect 1 件 + `defect.extras.session_findings` + セッションシート + 再現ケース起票の推奨規範）・6.4（セッションシートの evidence 保存）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 4 章（extras 代表キー `session_findings`）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md`（fail 時 defect 3 点セット）、`${CLAUDE_PLUGIN_ROOT}/references/severity-policy.md`（severity 判定基準）。

## 期待動作

- チャーター提示 → 開始確認 → セッション（AI は書記 + 操作補助）→ 終了聴取（セッションノート・発見事象・PROOF 振り返り）の流れで実施する（case の主系フローは test-run-scenario evals case-11 と同型。本ケースは発見事象の記録側を検証する）
- **代表 defect**: 発見 2 件のうち最重要の 1 件（全角スペース検索のエラー画面）を defect 3 点セット（severity〔severity-policy.md で判定〕・reproduction_steps〔人間の観察 + AI が把握する環境情報で構成〕・test_data・evidence）として記録する
- **session_findings**: 全 2 件の発見事象を `defect.extras.session_findings`（list）に記録する（軽微な折り返し崩れも欠落させない）
- **セッションシート**: 発見事象一覧（再現手順メモ付き）を含む固定見出しのセッションシートを `evidence/{run_id}/{case_id}/session-sheet.md` へ保存し evidence に含める
- **再現ケース起票の推奨**: 発見事象ごとに再現用の通常ケース（`review_status: draft`）の起票を推奨として**案内する**（起票自体は test-design の責務・revision 規則の既存経路。実行スキルは test-cases.yaml を書き換えない）
- **fail エビデンスの代替取得**: ユーザーからエビデンスを受領できない場合は AI が代替取得を試み（Playwright MCP 到達可能時の画面再取得等）、それも不可なら聴取した申告内容を `human-report.md` として `evidence/{run_id}/{case_id}/` へ保存し evidence 化する（manual-execution.md 4 章）
- `executed_by: human-assisted` で記録し、人間の申告を脚色・補完しない（申告されていない発見・再現性をでっち上げない）
- scope 全件について 1 エントリを返す
- test-results.yaml / test-cases.yaml を Edit / Write しない（返却のみ + 起票は案内のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `evidence/R20260719-110000/TC-FUNC-022/session-sheet.md`（発見事象一覧 2 件・再現手順メモ付き）+ 補助取得したスクリーンショット等。test-results.yaml / test-cases.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-functional" / 受領 run_id / results 1 件が fail・executed_by: human-assisted・defect 3 点セット + `extras.session_findings` 2 件）+ 再現ケース draft 起票の推奨案内 |
| 終了状態 | fail を記録して返却（発見 2 件とも記録に残り、報告書・再テストの既存経路に乗る） |

## 関連ケース

- case-07: manual-assist × 対話（個別ケースの人手確認。human-assisted 記録の同系）
- case-08: manual-assist × 非対話（skipped + reason の縮退側。exploratory も同じ縮退機構）
- case-02: AI 自動実行の表示不一致 fail（defect 3 点セットの自動実行側との対比。探索セッションでは代表 1 件 + session_findings に全件を残す点が異なる）
