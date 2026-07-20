# case-09 manual-assist ケース × 対話モード（人手確認して human-assisted 記録・機微情報マスキング）

`automation: manual-assist` の security スコープのケースについて、対話時はユーザーに手動確認を依頼し、結果を `executed_by: human-assisted` で記録し、報告された機微情報をマスクすることを検証する。非対話モードで skipped + reason になる分岐は case-10 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-173000` / ケース: `[TC-SEC-030]`（`automation: manual-assist`。多要素認証デバイスの実操作を伴うログイン確認・管理コンソール上の権限設定の目視確認など人手が不可欠なケース）/ アプリ情報あり |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・対話） |
| 前提 | 対象はテスト環境。対話モード（非対話モードで skipped + reason になる分岐は case-10） |

## 分岐の根拠

SKILL.md「実行モード判定」の manual-assist 分岐（対話時は `${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` に従いユーザーに手動確認を依頼し `executed_by: human-assisted` で記録・非対話時は skipped + reason）、`${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` 2 章（提示 3 要素: 確認対象・手順・判断基準〔承認済みケース記載の範囲〕）・3 章（結果聴取の選択肢と AskUserQuestion 設計）・4 章（人間提供エビデンスの受領・移送・マスキング）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 9 章（非対話既定値表: manual-assist は実行せず skipped + reason 記録）・4 章（executed_by の enum）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` 2 章（automation→executed_by 対応: manual-assist → human-assisted）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（skipped の意味論）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 5 章（機微情報マスキング）。

## 期待動作

- **対話時（主系）**: ユーザーに手動確認（確認対象・手順・承認済みケース記載の範囲であること）を依頼し、結果（pass / fail）を受けて `executed_by: human-assisted` で記録する。fail 時は defect 3 点セットを収集する
- ブラウザ・API で自動実行したかのように偽装しない（executed_by を `playwright-mcp` / `api` と誤記しない・結果を捏造しない）
- ユーザーから報告された確認結果・提供エビデンスに認証情報等の機微情報が含まれる場合は、保管・返却の前にマスクする（evidence-policy.md 5 章。生の値を actual / reason / チャット出力へ記載しない）
- 人手確認の依頼内容も承認済みケースに記載された範囲に限定する（範囲外の操作を依頼しない）
- **非対話時（対比）**: 人手介在ができないため skipped + reason で返す（詳細は case-10。execution-policy.md 9 章）
- scope 全件について 1 エントリを返す
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 人手確認時: 取得できた確認記録（ユーザー提供のスクリーンショット等はマスク済み状態で evidence/ へ）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-security" / 受領 run_id / results 1 件・executed_by: human-assisted）。機微情報はマスク済み |
| 終了状態 | 人手確認結果を記録して返却（非対話 skipped は case-10） |

## 関連ケース

- case-10: 同じ manual-assist ケースの非対話モード（skipped + reason で返す分岐）
- case-02: ブラウザ操作で自動実行される pass ケース（executed_by: playwright-mcp）との対比
- case-04: 機微情報マスキングの本体挙動（人手確認の結果にも同じ規約が適用される）
- case-05: MCP 未ロードによる skipped（実行手段不在の別要因）との対比
- case-06: 破壊的操作・対象外領域の skipped（実施しない判断の別分岐）との対比
