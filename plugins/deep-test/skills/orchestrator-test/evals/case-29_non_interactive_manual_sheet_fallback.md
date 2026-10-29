<!-- R13-EVAL-ORCH-29-SENTINEL-v1 -->
# case-29 非対話フルフローの手動手順書一括生成（Phase 5 手順 0.5 → manual-sheet= 引き渡し → skipped 縮退）

非対話フルフローで scope に手動系ケース（`automation: manual-assist` / `exploratory`）を含む場合に、Phase 5 手順 0.5 で `generate_manual_sheet.py` による手順書（チャーターシート）の一括生成 → 実行スキルへの `manual-sheet={path}` 付与 → skipped + reason（手順書パス）の record までを行い、生成失敗時はフェイルオープンで続行することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「--non-interactive でこのアプリをテストして」 |
| 前提 | フルフロー。scope に `automation: manual-assist` 1 件（functional・TC-FUNC-010）と `exploratory` 1 件（uat・TC-UAT-006）を含む。既存 target-slug は 1 件のみ。venv 構築済み |

## 分岐の根拠

SKILL.md「実行フロー」Phase 5 の手動実施ケース節（非対話時は start-run 前に手順書を一括生成して skipped + reason〔手順書パス〕へ縮退・生成失敗はフェイルオープン）とチェックリスト（非対話時、手動実施ケースの skipped reason に手順書パスが記録されている〔生成失敗時は理由のみで可〕）、references/flow.md 3 章（ゲート順序: 手動手順書の一括生成は非対話時のみ実施する Phase 5 手順 0.5。ゲートではなく生成失敗はフェイルオープンで続行）・6 章 Phase 5 手順 0.5（`generate_manual_sheet.py` の呼出形: `--cases` / `--ids`〔scope 内の手動系ケース ID の CSV〕/ `--out` / `--target`。exit code: 0 = 成功 / 2 = 対象なし / 1 = エラー / 64 = 引数不正。成功時は生成パスを手順 2 の Skill args `manual-sheet={path}` として引き渡す）・6 章手順 2（レベル内の cases= は自動 → 手動の順・非対話・生成成功時のみ manual-sheet= を付与）、プラグイン共通 references/execution-policy.md 9 章（非対話既定値表: manual-assist は手順書・exploratory はチャーターシート様式で一括生成し skipped + reason に手順書パス）、references/manual-execution.md 7 章（非対話縮退・reason 形式・起動主体はオーケストレータのみ・フェイルオープン）。

## 期待動作

- 人間承認ゲートは AskUserQuestion なしでスキップし（case-05 の既定値）、MCP ゲート・environment up（手順 0）通過後・start-run 直前に **手順 0.5** を実施する
- scope 内の手動系ケースを select 出力の `details.automation` で判別し、`generate_manual_sheet.py` を venv 経由で**一括起動**する（`--ids "TC-FUNC-010,TC-UAT-006"`。手動系ケース 0 件の場合は本手順自体を実施しない）
- **生成成功（exit 0）時**: stdout の生成パス（`{base}/{target-slug}/manual/manual-sheet_{yyyyMMdd-HHmmss}.md`）を、手動系ケースを含むレベルへの実行スキル委譲 args に `manual-sheet={path}` として付与する。レベル内の cases= は自動 → 手動の順に並べる
- 実行スキルが返す skipped + reason（手順書パス入り）を `results_manager.py record` 経由で 1 件ずつ記録する（test-results.yaml の Edit / Write 直接編集なし）
- **生成失敗（exit 非 0）時（対比）**: フェイルオープンで続行する（フローを止めない・エラー中断しない）。exit 1（一般エラー）/ 2（対象ケースなし）/ 64（引数パースエラー）の**いずれも同一のフェイルオープン扱い**とする。`manual-sheet=` を付与せず、実行スキルは従来どおり理由のみの skipped で返す。失敗理由は annotate で所見化してよい
- 手順書の生成はオーケストレータのみが行う（実行スキルにスクリプトを起動させない）
- 対話時は手順 0.5 を実施しない（手動ケース到達時に実行スキルが manual-execution.md に従いユーザーへ確認する側。「後で実施」選択時のみ同型のオンデマンド生成）
- 手動系ケースの skipped は報告書の未確認事項に転記され、人員整備後の ng-only 再テスト対象になる

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{base}/{target-slug}/manual/manual-sheet_{yyyyMMdd-HHmmss}.md`（manual-assist 節 + exploratory のチャーターシート節を含む一括手順書）・test-results.yaml（record 経由で TC-FUNC-010 / TC-UAT-006 が skipped + reason〔手順書パス入り〕）・Markdown 既定の報告書 |
| 標準出力（要約） | SKILL.md「引き渡し」の正常フォーマット（run_id・レベル別集計・未確認事項に手動系 skipped 2 件・報告書パス）。生成失敗時はフェイルオープンの旨と理由のみ skipped |
| 終了状態 | run status=completed（手動系ケースは skipped のまま完了。生成失敗でも中断しない） |

## 関連ケース

- case-05: 非対話モードの既定値動作の基本形（本ケースは手順書生成 = 手順 0.5 の詳細）
- case-28: 対話時の人間承認ゲートにおける手動件数提示（対話側では手順 0.5 を実施しない）
- case-01: フルフロー正常系（Phase 5 の record・finish-run の既存経路は同一）
