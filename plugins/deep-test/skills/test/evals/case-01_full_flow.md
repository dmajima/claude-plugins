# case-01 フルフロー正常系（全フェーズ委譲・全ゲート通過）

初回対象に対するフルフローで、Phase 0〜7 の委譲順序・4 ゲートの通過・results_manager.py による実績記録が規範どおりに行われることを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「このアプリをテストして」（または `/deep-test:test`） |
| 前提 | 対象 target-slug は未作成（既存 slug なし）。Playwright MCP はロード済み。設計レビューは 1 回で PASS、実行結果はすべて pass |

## 分岐の根拠

SKILL.md「実行モード判定」（既定 = フル: Phase 0→1→2→3→4→5→6→7）、SKILL.md「実行フロー」Phase 0〜7、references/flow.md 2 章（フェーズ入出力）・3 章（ゲート判定の固定順序: select → 承認済みケース → 人間承認 → MCP → start-run）、プラグイン共通 references/execution-policy.md 1 章（ゲート定義）。

## 期待動作

- Phase 0: 既存 slug がないため新規 slug 名をユーザーに確認して作成し（AskUserQuestion）、venv 準備後に `results_manager.py init` を実行する
- Phase 1: `Skill(deep-test:test-setup)` で環境検出を受領する（MCP ロード済みのため再起動ハンドオフは出さない）
- Phase 2〜3: `Skill(deep-test:test-design)` → `Skill(deep-test:test-review, context=design)` の順に起動し、PASS 受領後に test-design へ approved 化を委譲する
- Phase 4: `results_manager.py select --mode full` で scope を機械的に確定し、`draft_cases` が空であることを確認（承認済みケースゲート）→ AskUserQuestion でケース数・対象レベル・想定所要時間・破壊的操作の有無を提示（人間承認ゲート）→ ToolSearch で `mcp__playwright__*` の実利用可否を確認（MCP ゲート）する
- Phase 5: `start-run` で run_id を採番 → scope をレベル別にグループ化し test-run-* を**レベル順に逐次** Skill 起動（並列起動しない）→ 中間結果の results[] を 1 件ずつ `record` → 全レベル完了後 `finish-run`（status=completed）
- test-results.yaml を Edit / Write で直接編集しない（すべて results_manager.py 経由）
- Phase 6: `Skill(deep-test:test-review, context=results)` を起動する
- Phase 7: `validate` が ok であることを確認してから `Skill(deep-test:test-report)` を起動する（報告形式の AskUserQuestion は test-report 側）
- 引き渡し: run_id・レベル別集計（summary）・報告書パス・未確認事項を含めて報告する（SKILL.md「引き渡し」）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | test-plan.md / test-cases.yaml（設計レビュー PASS 後は approved）・test-results.yaml（results_manager.py の init → start-run → record → finish-run 経由で更新。Edit / Write の直接編集なし）・報告書（test-report がセッション作業領域直下に生成） |
| 標準出力（要約） | SKILL.md「引き渡し」の正常完了フォーマット: run_id・レベル別集計（summary）・報告書パス・未確認事項 |
| 終了状態 | Phase 0〜7 をすべて完了。run status=completed（全ケース pass） |

## 関連ケース

- case-03: MCP 未ロード時の停止分岐（本ケースの MCP ゲート通過と対）
- case-04: 設計レビュー NEEDS REVISION の遡行分岐（本ケースの 1 回 PASS と対）
- case-05: 同フローの非対話版（確認スキップ・既定値）
