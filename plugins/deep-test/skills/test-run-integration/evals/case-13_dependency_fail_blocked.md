# case-13 依存先ケース fail → 後続ケース blocked（IT-a）

`depends_on` で依存を宣言したケースの依存先が同一 run 内で fail するケース。後続ケースを実行せず blocked + reason（依存先ケース ID とその結果）で記録することを検証する。既存 functional/scenario の同型ケース（依存元 fail → 後続 blocked）を結合レベルで確認する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-web / run_id=R20260722-100000 / 対象ケース TC-ITA-001（画面間のデータ受け渡し。実行すると fail になる）・TC-ITA-002（depends_on: [TC-ITA-001]）/ 対象 URL https://localhost:5001 |
| 起動形態 | 委譲（オーケストレータ test から Skill ツール経由・MCP ゲート通過済み） |
| 前提 | MCP 利用可・連携対象モジュールが同一テスト環境に統合済み。TC-ITA-001 が欠陥により fail する状態 |

## 分岐の根拠

SKILL.md「実行フロー」手順 3（ケース逐次実行: 共通手順の preconditions 確認）、references/integration-execution.md の status 分岐表（`depends_on` の依存先が同一 run 内で fail / blocked → blocked + reason・依存先ケース ID とその結果を記録）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md`（依存元 fail 時、後続ケースは blocked + reason で記録）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` 2 章（depends_on）・`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（blocked の意味論: 依存ケースの fail）。

## 期待動作

- TC-ITA-001 を実行して fail と判定し、defect 3 点セット（環境情報含む再現手順・検証データ・エビデンス）を収集する（case-03 と同じ fail 処理）
- TC-ITA-002 の実行前に depends_on を確認し、依存先（TC-ITA-001）が同一 run 内で fail であることを検出する
- TC-ITA-002 の連携確認（ブラウザ操作・API 補助確認）を実行せず **blocked** と判定し、reason に依存先ケース ID（TC-ITA-001）とその結果（fail）を記録する
- blocked のケースに defect・severity を付与しない
- 依存先が fail でも後続を強行実行しない（無意味な失敗の量産・環境汚染を防ぐ）
- scope 全件（2 エントリ: fail 1 件 + blocked 1 件）を返却する
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | TC-ITA-001 の fail 証跡（失敗時点スクリーンショット・マスク済み API レスポンス等、defect 3 点セットの evidence）を evidence/R20260722-100000/TC-ITA-001/ へ移送・保存（TC-ITA-002 は実行しないためエビデンスなし）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-integration" / 受領 run_id / results 2 件。fail エントリは severity 付き defect、blocked エントリは依存先 ID と結果を記した reason 付き）。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 2 件を 1 エントリずつ返却（TC-ITA-001 fail / TC-ITA-002 blocked＝依存先 fail。後続の強行実行なし） |

## 関連ケース

- case-03: fail 処理そのもの（3 点セット収集・API エビデンス）
- case-02: 外部接続不可時のスタブポリシー判断（blocked とは別要因の縮退）
- test-run-functional case-05 / test-run-scenario case-02: 他レベルの同型（依存元 fail → 後続 blocked）
