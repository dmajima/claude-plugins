# case-08 manual-assist ケース × 非対話モード（skipped + reason で返却）

`automation: manual-assist` の unit スコープのケースを **非対話モード**で受領した場合、人手介在ができないため実行せず、`status: skipped` + reason で返す（テストランナーで自動実行したかのように偽装しない）ことを検証する。対話モード（人手確認して human-assisted 記録）の主系は case-07 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=sample-api` / `run_id=R20260717-162000` / ケース: `[TC-UNIT-010]`（`automation: manual-assist`。自動実行が難しく人手での結果確認を要するケース）/ 対象プロジェクト情報 / `--non-interactive` / `manual-sheet=manual/manual-sheet_20260717-162000.md`（オーケストレータが Phase 5 手順 0.5 で一括生成した手順書のパス。非対話・生成成功時のみ付与） |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・非対話） |
| 前提 | 非対話モードのため人手確認を求められない |

## 分岐の根拠

SKILL.md「実行モード判定」（`automation: manual-assist` のケース: 非対話時は skipped + reason）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 9 章（非対話既定値表: manual-assist は実行せず skipped + reason 記録）・4 章（中間結果フォーマット・scope 全件返却）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（skipped の意味論）、`${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` 7 章（非対話縮退: 手順書生成の起動主体はオーケストレータのみ・実行スキルは `manual-sheet=` 受領パスを reason に転記・フェイルオープン）・5 章（skipped = 人間の応答可能性の不在の意味論）。

## 期待動作

- 人手介在ができないため実行せず、`status: skipped` + `reason` で返す。`manual-sheet=` で受領した手順書パスを reason に転記する（例: 「非対話のため未実施。手順書: manual/manual-sheet_20260717-162000.md」。manual-execution.md 7 章の形式。実行スキル自身は `generate_manual_sheet.py` を起動しない）
- `manual-sheet=` を受領していない場合（オーケストレータ側の生成失敗 = フェイルオープン）は、従来どおり理由のみ（例: 「非対話モードのため人手確認ケースは未実施」）の skipped で返す（execution-policy.md 9 章）
- テストランナーで自動実行したかのように偽装しない（skipped を「pass」「問題なし」に書き換えない・executed_by を `test-framework` と誤記しない）
- ユーザーへの手動確認依頼（AskUserQuestion 相当）を行わない（非対話モード）
- scope 全件について 1 エントリ（skipped + reason）を返す
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（実行しないためエビデンスなし。test-results.yaml へも書き込まない） |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-unit" / 受領 run_id / results 1 件が skipped + reason） |
| 終了状態 | skipped + reason で返却（人手確認を求めず・自動実行に偽装しない） |

## 関連ケース

- case-07: 同じ manual-assist ケースの対話モード（人手確認して executed_by: human-assisted で記録する主系）
- case-03: ランナー不在による skipped（実行手段不在の別要因）との対比
