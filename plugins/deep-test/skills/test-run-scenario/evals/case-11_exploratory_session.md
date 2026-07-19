<!-- R13-EVAL-SCEN-11-SENTINEL-v1 -->
# case-11 exploratory ケース × 対話モード（チャーターベース探索セッションを human-assisted 記録）

`automation: exploratory` の uat スコープのケースについて、対話時はチャーター提示 → タイムボックス案内 → セッション実施（AI は書記 + 操作補助）→ 終了聴取（ノート・発見・PROOF）→ セッションシートの evidence 化を経て、`executed_by: human-assisted` で記録することを検証する。発見事象の記録先は fail 時 = `defect.extras.session_findings`・defect 化する発見がない pass 時 = results[] 直下の `extras.session_findings`。非対話モードでチャーターシート縮退（skipped + reason）になる分岐は case-12 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260719-100000` / ケース: `[TC-UAT-006]`（`automation: exploratory`。title「受注登録まわりの探索セッション（入力揺らぎと帳票整合）」・steps = 探索指針・expected = 発見目標・`timeout_sec: 3600` = タイムボックス 60 分）/ アプリ情報: `https://localhost:5001` |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・対話） |
| 前提 | 対話モード（非対話のチャーターシート縮退は case-12）。Playwright MCP はロード済み（AI の操作補助に使用可）。セッション開始が成立する（開始不能分岐は case-14）。主系シナリオ: 軽微な発見 1 件（一覧画面の並び順の揺らぎ・再現性 sometimes）が申告されるが defect 化には至らず総合結果は **pass** |

## 分岐の根拠

SKILL.md「実行モード判定」の manual-assist / exploratory 分岐（対話時は `${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` に従いユーザーに確認を依頼し `executed_by: human-assisted` で記録）、`${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` 3 章（exploratory セッション開始・終了の聴取設計）・6 章（exploratory セッション規範: チャーター表現・タイムボックス・セッションの進め方・セッションシート・発見事象の記録）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 8 章（`automation: exploratory` の例外: timeout_sec はタイムボックスであり超過 = blocked を適用しない）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` 2 章（automation→executed_by 対応: exploratory → human-assisted・steps / expected の意味論注記）。

## 期待動作

- **セッション開始**: チャーター（title・steps = 探索指針）・発見目標（expected）・タイムボックス（timeout_sec 3600 = 60 分）・記録方法を提示し、AskUserQuestion で開始可否を確認する（選択肢: 開始 / 後で実施〔チャーターシート縮退〕/ 中止。manual-execution.md 3 章）
- **セッション中**: 人間が探索を主導し、AI は書記 + 操作補助（セッションノートの記録・画面遷移・データ投入・スクリーンショット取得）に徹する。AI の補助操作と人間の申告を混同して記録しない
- **タイムボックス**: 満了しても blocked にしない（満了 = セッション正常終了として結果判定へ進む。execution-policy.md 8 章の適用除外）。セッション開始不能（対象未起動等の前提不成立）のみ blocked + reason
- **セッション終了聴取**: (1) セッションノート（何を試したか）(2) 発見事象（バグ・気付き。件数分）(3) PROOF 観点（Past / Results / Obstacles / Outlook / Feelings）の振り返りを聴取し、総合結果を選択肢で確定する（pass = 重大発見なし・完遂 / fail = 欠陥発見 / blocked = 探索不能）
- **セッションシート**: 聴取内容を固定見出し（チャーター / タイムボックス実績 / セッションノート / 発見事象一覧 / PROOF 振り返り / 総合結果）で Markdown 整形し、`evidence/{run_id}/{case_id}/session-sheet.md` へ保存して結果の `evidence` に含める
- **記録**: `executed_by: human-assisted` で返却する（playwright-mcp と誤記しない）。人間の申告を脚色・補完しない（聴取していない実測値・結果をでっち上げない）。fail 時は最重要の発見 1 件を defect 3 点セットに記録し、全発見を `defect.extras.session_findings`（list）に含める。defect 化する発見がないセッション（fail に至らない）の発見事象は results[] 直下の `extras.session_findings` に記録する（manual-execution.md 6.5。主系では前提の軽微な発見 1 件〔並び順の揺らぎ・sometimes・defect 化なし〕をここに記録して pass で返す）
- uat ケースを人手セッションで pass にしても「受入完了」と結論しない（最終受入判断は人間の責務）
- scope 全件について 1 エントリを返す
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `evidence/R20260719-100000/TC-UAT-006/session-sheet.md`（固定見出しのセッションシート）+ 補助取得したスクリーンショット等（あれば同ディレクトリへ移送）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-scenario" / 受領 run_id / results 1 件・executed_by: human-assisted・evidence に session-sheet.md を含む・fail 時は defect + extras.session_findings） |
| 終了状態 | セッション結果を記録して返却（非対話のチャーターシート縮退は case-12） |

## 関連ケース

- case-12: 同じ exploratory ケースの非対話モード（チャーターシート縮退・skipped + reason で返す分岐）
- case-07: manual-assist × 対話（個別ケースの人手確認。exploratory と同じ human-assisted 記録・聴取の型の同系）
- case-03: UAT 観点の検証と受入判断の分離（人手セッションでも同じ免責が適用される）
- case-01: Playwright MCP で AI が自動実行する pass ケース（executed_by: playwright-mcp。automation: playwright の「AI 探索」との用語区別は manual-execution.md 1.3）
- case-14: セッション開始が不成立（blocked）、または開始聴取で「後で実施」/「中止」が選択された分岐
