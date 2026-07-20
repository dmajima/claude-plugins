# case-07 応答が得られずタイムアウト → blocked（閾値超過 fail との判定分岐）

計測対象の操作に対して応答自体が得られず、ケースタイムアウトを超過して計測が完了しないケース。閾値超過 fail（case-02）と区別して blocked + reason で記録することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-165000` / ケース: `[TC-PERF-004]`（expected: 一覧表示 3 秒以内）/ アプリ情報: `https://localhost:5001` |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ） |
| 前提 | Playwright MCP ロード済み / 対象操作が応答を返さず、ケースタイムアウト（既定 120 秒・`timeout_sec` で上書き可）を超過しても計測が完了しない（ハング） |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/performance-execution.md` 3.1（応答不能・タイムアウト〔計測不能〕の分岐: ハングで計測自体が完了しない場合は blocked + reason〔タイムアウト〕とし切り分けを actual に記す）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 8 章（ケースタイムアウト超過は blocked + reason〔経過時間・最後に完了したステップ〕）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（blocked = テスト論理上のブロック・タイムアウトによるハングを含む / fail = 期待結果との不一致）。

## 期待動作

- 対象操作を実行し、応答が得られないままケースタイムアウトを超過したことを検出する
- 計測値をでっち上げず、当該ケースを `status: blocked` + `reason`（タイムアウト発生の旨・経過時間・最後に完了したステップ）で記録する（execution-policy.md 8 章）
- **閾値超過 fail（case-02）と区別する**: 応答は得られたが遅い（実測値 > 閾値）なら fail、応答自体が得られず計測が完了しない（ハング）なら blocked。切り分けの根拠を actual に記す（performance-execution.md 3.1）
- blocked は `defect` を持たない（yaml-schema-results.md 6 章。3 点セットは不要・reason 必須）
- 次ケースへ進む（1 ケースの blocked で run 全体を止めない）
- scope 全件について 1 エントリを返す
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | タイムアウトまでに取得できた部分的な計測ログ・スクリーンショット（あれば evidence/ へ移送）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-performance" / 受領 run_id / 当該ケース status: blocked + reason・defect なし） |
| 終了状態 | 当該ケースを blocked で記録し次ケースへ継続（閾値超過 fail とは別判定） |

## 関連ケース

- case-02: 閾値超過 fail（応答は得られたが遅い分岐との対比）
- case-05: MCP 未ロードによる skipped（実行手段不在との対比）
- case-01: 閾値内 pass（正常計測）
