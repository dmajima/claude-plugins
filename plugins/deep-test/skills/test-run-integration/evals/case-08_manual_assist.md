# case-08 manual-assist ケース × 対話モード（人手確認して human-assisted 記録）

`automation: manual-assist` の結合ケースについて、対話時はユーザーに手動確認を依頼し、結果を `executed_by: human-assisted` で記録することを検証する。非対話モードで skipped + reason になる分岐は case-09 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-161000` / ケース: `[TC-ITB-005]`（`automation: manual-assist`。外部システムの担当者による目視確認が必要な連携）/ アプリ情報あり |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・対話） |
| 前提 | 対話モード（非対話モードで skipped + reason になる分岐は case-09）。ケースは人手介在でのみ確認可能 |

## 分岐の根拠

SKILL.md「実行モード判定」（`automation: manual-assist` のケース: 対話時はユーザーに手動確認を依頼し `executed_by: human-assisted` で記録・非対話時は skipped + reason）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 9 章（非対話既定値表: `automation: manual-assist` のケースは実行せず skipped + reason 記録）・4 章（中間結果フォーマット: executed_by の enum）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` 2 章（automation enum と executed_by の対応: manual-assist → human-assisted）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（skipped の意味論）。

## 期待動作

- **対話時（主系）**: ユーザーに手動確認（確認対象・手順・判断基準を提示のうえ）を依頼し、確認結果（pass / fail）を受けて `executed_by: human-assisted` で結果を記録する。fail の場合は defect 3 点セットを収集する
- executed_by は人手確認を行った場合のみ `human-assisted`（yaml-schema-cases.md 2 章の automation→executed_by 対応）。自動実行したかのように偽装しない
- **非対話時（対比）**: 人手介在ができないため skipped + reason で返す（詳細は case-09。execution-policy.md 9 章）
- scope 全件について 1 エントリを返す
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 人手確認 pass 時: 確認結果のエビデンス（取得できた場合）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-integration" / 受領 run_id / results 1 件・executed_by: human-assisted） |
| 終了状態 | 人手確認結果を記録して返却（非対話 skipped は case-09） |

## 関連ケース

- case-09: 同じ manual-assist ケースの非対話モード（skipped + reason で返す分岐）
- case-01: 自動実行される IT-a ケース（automation: playwright）との対比
- case-07: 実行手段不在（MCP 未ロード）による skipped との対比
