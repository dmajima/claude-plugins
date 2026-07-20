<!-- R13-EVAL-SCEN-12-SENTINEL-v1 -->
# case-12 exploratory ケース × 非対話モード（チャーターシート縮退・skipped + reason にシートパス転記）

`automation: exploratory` の uat スコープのケースを**非対話モード**で受領した場合、セッションを開始せず `status: skipped` + reason で返し、オーケストレータから `manual-sheet=` で受領したチャーターシートパスを reason に転記することを検証する。対話モード（セッション実施の主系）は case-11 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260719-100000` / ケース: `[TC-UAT-006]`（`automation: exploratory`。case-11 と同一のチャーターケース）/ アプリ情報: `https://localhost:5001` / `--non-interactive` / `manual-sheet=manual/manual-sheet_20260719-100000.md`（オーケストレータが Phase 5 手順 0.5 で一括生成したチャーターシートのパス） |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・非対話） |
| 前提 | 非対話モードのため人間セッションを開催できない。チャーターシートはオーケストレータが生成済み（実行スキルは生成しない） |

## 分岐の根拠

SKILL.md「実行モード判定」の manual-assist / exploratory 分岐（非対話時は skipped + reason 記録。オーケストレータから `manual-sheet=` で手順書パスを受領した場合は reason に含める）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 9 章（非対話既定値表: exploratory は実行せずチャーターシート様式で手順書を一括生成し skipped + reason〔シートパスを含む〕を記録。生成はオーケストレータ・生成失敗時は従来どおり理由のみで skipped）、`${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` 7 章（非対話縮退: reason の形式・スクリプト起動主体はオーケストレータのみ・フェイルオープン）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（skipped = 実行手段不在〔人間の応答可能性の不在〕の意味論）。

## 期待動作

- 人間セッションを開催できないため**実行せず**、`status: skipped` + reason で返す（例: 「非対話のため未実施。手順書: manual/manual-sheet_20260719-100000.md」。manual-execution.md 7 章の形式）
- `manual-sheet=` で受領したチャーターシートパスを reason に**転記する**（実行スキル自身は `generate_manual_sheet.py` を起動しない。生成はオーケストレータの責務）
- `manual-sheet=` を受領していない場合（オーケストレータ側の生成失敗 = フェイルオープン）は、従来どおり理由のみ（例: 「非対話モードのため人手介在ケースは未実施」）の skipped で返す
- ユーザーへのセッション開始確認・聴取を行わない（非対話モード）
- 実行を偽装しない（executed_by を `playwright-mcp` と誤記しない・セッションシートやセッション結果を捏造しない・skipped を「問題なし」に書き換えない）
- 未実施の uat ケースを「受入完了」と結論しない（skipped は未確認のまま）
- scope 全件について 1 エントリ（skipped + reason）を返す
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（セッション未実施のためセッションシート・エビデンスを作らない。チャーターシートの生成はオーケストレータが実施済み。test-results.yaml へも書き込まない） |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-scenario" / 受領 run_id / results 1 件が skipped + reason〔チャーターシートパス入り〕・executed_by: human-assisted） |
| 終了状態 | skipped + reason で返却（セッションを開催せず・自動実行や受入完了に偽装しない） |

## 関連ケース

- case-11: 同じ exploratory ケースの対話モード（チャーター提示 → セッション実施 → human-assisted 記録の主系）
- case-08: manual-assist × 非対話（同じ縮退機構。`manual-sheet=` 受領時の reason への手順書パス転記・未受領時の理由のみフェイルオープンも同型）
- case-05: MCP 未ロードによる skipped（実行手段不在の別要因）との対比
- case-14: 対話モードでのセッション開始不能（blocked）/「後で実施」/「中止」の分岐（本ケースは非対話側）
