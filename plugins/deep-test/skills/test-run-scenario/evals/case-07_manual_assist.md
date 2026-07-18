# case-07 manual-assist ケース × 対話モード（人手確認して human-assisted 記録）

`automation: manual-assist` の system / uat スコープのケースについて、対話時はユーザーに手動確認を依頼し、結果を `executed_by: human-assisted` で記録することを検証する。非対話モードで skipped + reason になる分岐は case-08 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-171000` / ケース: `[TC-UAT-005]`（`automation: manual-assist`。帳票の印字イメージ・画面レイアウトの妥当性など人手の目視確認が不可欠な受入ケース）/ アプリ情報: `https://localhost:5001` |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・対話） |
| 前提 | 対話モード（非対話モードで skipped + reason になる分岐は case-08） |

## 分岐の根拠

SKILL.md「実行モード判定」の manual-assist 分岐（対話時はユーザーに手動確認を依頼し `executed_by: human-assisted` で記録・非対話時は skipped + reason。バッチ E 追記後の記載）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 9 章（非対話既定値表: manual-assist は実行せず skipped + reason 記録）・4 章（executed_by の enum）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` 2 章（automation→executed_by 対応: manual-assist → human-assisted）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（skipped の意味論）。

## 期待動作

- **対話時（主系）**: ユーザーに手動確認（確認対象・手順・判断基準の提示）を依頼し、結果（pass / fail）を受けて `executed_by: human-assisted` で記録する。`actual` に確認内容と結果（uat では受入観点の所見）を記述し、fail 時は defect 3 点セットを収集する
- Playwright MCP で自動実行したかのように偽装しない（executed_by を `playwright-mcp` と誤記しない・結果を捏造しない）
- uat ケースを人手確認で pass にしても「受入完了」と結論しない（最終受入判断は人間の責務）
- **非対話時（対比）**: 人手介在ができないため skipped + reason で返す（詳細は case-08。execution-policy.md 9 章）
- scope 全件について 1 エントリを返す
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 人手確認時: 取得できた確認記録（ユーザー提供のスクリーンショット等があれば evidence/ へ）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-scenario" / 受領 run_id / results 1 件・executed_by: human-assisted） |
| 終了状態 | 人手確認結果を記録して返却（非対話 skipped は case-08） |

## 関連ケース

- case-08: 同じ manual-assist ケースの非対話モード（skipped + reason で返す分岐）
- case-01: Playwright MCP で自動実行される pass ケース（executed_by: playwright-mcp）との対比
- case-05: MCP 未ロードによる skipped（実行手段不在の別要因）との対比
- case-03: UAT 観点の検証と受入判断の分離（人手確認でも同じ免責が適用される）
