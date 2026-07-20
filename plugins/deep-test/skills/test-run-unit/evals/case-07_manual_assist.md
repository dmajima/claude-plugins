# case-07 manual-assist ケース × 対話モード（人手確認して human-assisted 記録）

`automation: manual-assist` の unit スコープのケースについて、対話時はユーザーに手動確認を依頼し、結果を `executed_by: human-assisted` で記録することを検証する。非対話モードで skipped + reason になる分岐は case-08 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=sample-api` / `run_id=R20260717-162000` / ケース: `[TC-UNIT-010]`（`automation: manual-assist`。自動実行が難しく人手での結果確認を要するケース）/ 対象プロジェクト情報 |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・対話） |
| 前提 | 対話モード（非対話モードで skipped + reason になる分岐は case-08） |

## 分岐の根拠

SKILL.md「実行モード判定」（`automation: manual-assist` のケース: 対話時は `${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` に従いユーザーに手動確認を依頼し `executed_by: human-assisted` で記録・非対話時は skipped + reason）、`${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` 2 章（提示 3 要素: 確認対象・手順・判断基準）・3 章（結果聴取の選択肢と AskUserQuestion 設計）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 9 章（非対話既定値表: manual-assist は実行せず skipped + reason）・4 章（executed_by の enum）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` 2 章（automation→executed_by 対応: manual-assist → human-assisted）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（skipped の意味論）。

## 期待動作

- **対話時（主系）**: ユーザーに手動確認（確認対象・手順・判断基準を提示のうえ）を依頼し、結果（pass / fail）を受けて `executed_by: human-assisted` で記録する。fail 時は defect 3 点セットを収集する
- テストランナーで自動実行したかのように偽装しない（executed_by を `test-framework` と誤記しない・結果を捏造しない）
- **非対話時（対比）**: 人手介在ができないため skipped + reason で返す（詳細は case-08。execution-policy.md 9 章）
- scope 全件について 1 エントリを返す
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 人手確認時: 取得できた確認記録。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-unit" / 受領 run_id / results 1 件・executed_by: human-assisted） |
| 終了状態 | 人手確認結果を記録して返却（非対話 skipped は case-08） |

## 関連ケース

- case-08: 同じ manual-assist ケースの非対話モード（skipped + reason で返す分岐）
- case-01: テストランナーで自動実行される pass ケース（executed_by: test-framework）との対比
- case-03: ランナー不在による skipped（実行手段不在の別要因）との対比
