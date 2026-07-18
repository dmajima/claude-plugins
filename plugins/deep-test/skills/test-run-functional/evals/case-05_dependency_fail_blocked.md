# case-05 依存先ケース fail → 後続ケース blocked

`depends_on` で依存を宣言したケースの依存先が同一 run 内で fail するケース。後続ケースを実行せず blocked + reason（依存先ケース ID とその結果）で記録することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-web / run_id=R20260717-160000 / 対象ケース TC-FUNC-001（ログイン成功。実行すると fail になる）・TC-FUNC-002（depends_on: [TC-FUNC-001]）/ 対象 URL https://localhost:5001 |
| 起動形態 | 委譲（オーケストレータ test から Skill ツール経由・MCP ゲート通過済み） |
| 前提 | MCP 利用可・対象アプリ稼働中。TC-FUNC-001 が欠陥により fail する状態 |

## 分岐の根拠

SKILL.md「実行フロー」手順 4（preconditions 確認: 依存先 fail は blocked）、references/functional-execution.md 5 章（分岐表: depends_on の依存先が同一 run 内で fail / blocked → blocked + reason）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 5 章（テストデータ分離: 依存元 fail 時、後続ケースは blocked + reason で記録）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` 2 章（depends_on）・`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（blocked の意味論: 依存ケースの fail）。

## 期待動作

- TC-FUNC-001 を実行して fail と判定し、defect 3 点セットを収集する（case-02 と同じ fail 処理）
- TC-FUNC-002 の実行前に depends_on を確認し、依存先（TC-FUNC-001）が同一 run 内で fail であることを検出する
- TC-FUNC-002 のブラウザ操作を実行せず **blocked** と判定し、reason に依存先ケース ID（TC-FUNC-001）とその結果（fail）を記録する
- blocked のケースに defect・severity を付与しない
- 依存先が fail でも後続を強行実行しない（無意味な失敗の量産・環境汚染を防ぐ）
- scope 全件（2 エントリ: fail 1 件 + blocked 1 件）を返却する

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | TC-FUNC-001 の fail 証跡（失敗時点スクリーンショット・コンソールログ等、defect 3 点セットの evidence）を evidence/R20260717-160000/TC-FUNC-001/ へ移送・保存（TC-FUNC-002 は実行しないためエビデンスなし）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-functional" / 受領 run_id / results 2 件。fail エントリは severity 付き defect、blocked エントリは依存先 ID と結果を記した reason 付き）。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 2 件を 1 エントリずつ返却（TC-FUNC-001 fail / TC-FUNC-002 blocked＝依存先 fail。後続の強行実行なし） |

## 関連ケース

- case-02: fail 処理そのもの（3 点セット収集）
- case-03: タイムアウトによる blocked（blocked の別要因）
