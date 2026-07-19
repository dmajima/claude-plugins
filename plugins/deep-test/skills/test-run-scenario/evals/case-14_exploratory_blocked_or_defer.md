<!-- R13-EVAL-SCEN-14-SENTINEL-v1 -->
# case-14 exploratory ケース × 対話でセッション開始不能（blocked + reason）と開始聴取の「後で実施」/「中止」分岐

`automation: exploratory` の uat スコープのケースについて、**セッション開始不能**（SUT 未起動等の前提不成立）を `status: blocked` + reason で記録することを主分岐として検証し、セッション開始聴取で**「後で実施」**（チャーターシート縮退 → skipped + シートパス転記）・**「中止」**（実施せず記録もしない）が選択された場合の帰結を副分岐として明記する。セッション開始が成立する主系は case-11 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260719-130000` / ケース: `[TC-UAT-006]`（`automation: exploratory`。case-11 と同一のチャーターケース・`timeout_sec: 3600` = タイムボックス 60 分）/ アプリ情報: `https://localhost:5001` |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・対話） |
| 前提 | 対話モード。主分岐では対象 `https://localhost:5001` が未起動（接続拒否）でセッションを開始できない。副分岐では（対象の到達可否によらず）開始聴取でユーザーが「後で実施」または「中止」を選択する |

## 分岐の根拠

SKILL.md「実行モード判定」の manual-assist / exploratory 分岐（対話時は `${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` に従う）、`${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` 3 章（exploratory セッション開始の聴取: 選択肢 開始 / 後で実施〔チャーターシート縮退。7 章〕/ 中止。中止 = 実施せず記録もしない〔scope から外れず後続 run で再対象化・`ids` 指定の再実行手段を案内〕）・6.2（セッション開始不能〔対象未起動等の前提不成立〕はテスト論理上のブロックとして blocked + reason で記録する。タイムボックス満了 = 正常終了とは別事象）・5 章（「後で実施」= オンデマンド生成 → skipped + reason〔シートパス〕）・7 章（スクリプト起動主体はオーケストレータのみ・フェイルオープン）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（blocked = テスト論理起因 / skipped = 実行手段・応答可能性の不在の使い分け）。

## 期待動作

- **主分岐（セッション開始不能 = blocked）**: チャーター提示・開始準備の段階で対象未起動（接続拒否等）によりセッションを開始できない場合、テスト論理上のブロックとして `status: blocked` + reason（開始不能の理由）を `executed_by: human-assisted` で記録する（manual-execution.md 6.2）。タイムボックス超過 = blocked を適用しない規約（正常終了扱い）と混同しない
- blocked を skipped と混同しない（blocked = 前提不成立のテスト論理起因 / skipped = 実行手段・人間の応答可能性の不在。yaml-schema-results.md 6 章）
- セッションを開始していないため、セッションシート・セッションノート・発見事象を捏造しない（session-sheet.md を作らない）
- **副分岐 1（「後で実施」）**: 開始聴取で「後で実施」が選択された場合はチャーターシート縮退とし、オーケストレータによる同型のオンデマンド生成（実行スキルは `generate_manual_sheet.py` を起動しない）を経て、`status: skipped` + reason にシートパスを転記する（例: 「後で実施が選択されたため未実施。手順書: manual/manual-sheet_20260719-130500.md」。生成失敗時は理由のみのフェイルオープン）
- **副分岐 2（「中止」）**: 開始聴取で「中止」が選択された場合は当該セッションを実施せず**記録もしない**（result エントリを作らない。manual-execution.md 3 章）。当該ケースは scope から外れたわけではなく後続 run で再対象化されるため、ユーザーへ再実行手段（`ids` 指定での再テスト）を案内する
- scope 全件について 1 エントリを返す（**中止選択時のみ例外**として当該ケースのエントリを作らない。3 章の中止規範）
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 主分岐・副分岐 2: なし（セッション未実施のためセッションシートを作らない）。副分岐 1 のみ `manual/manual-sheet_20260719-130500.md`（チャーターシート節。オーケストレータによるオンデマンド生成）。いずれも test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-scenario" / 受領 run_id / 主分岐: results 1 件が blocked + reason・executed_by: human-assisted。副分岐 1: skipped + reason〔シートパス入り〕。副分岐 2: 当該ケースのエントリなし + `ids` 指定での再実行案内） |
| 終了状態 | 主分岐: blocked を記録して返却（対象の起動後、ng-only 再テストの対象になる） |

## 関連ケース

- case-11: 同じ exploratory ケースの対話主系（セッション開始が成立して pass 終端へ至る側。開始不能分岐は本ケース）
- case-12: exploratory × 非対話（チャーターシート縮退の非対話側。「後で実施」の対話縮退と同型機構）
- case-13: manual-assist ×「後で実施」選択（個別ケース側の同型縮退）
- case-05: MCP 未ロードによる skipped（実行手段不在。テスト論理起因の blocked との使い分けの対比）
- test-run-functional evals case-12: exploratory の fail 終端（発見事象の defect 化・session_findings 記録）
