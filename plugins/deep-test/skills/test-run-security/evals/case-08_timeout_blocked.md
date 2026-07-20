# case-08 ケースタイムアウト超過 → blocked + reason

セキュリティチェックの実行がケースタイムアウトを超過して完了しないケース。当該ケースを blocked + reason で記録し次ケースへ進むことを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-168000` / ケース: `[TC-SEC-010, TC-SEC-011]`（TC-SEC-010=応答が返らずハングする確認 / TC-SEC-011=後続の通常ケース）/ アプリ情報あり |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ） |
| 前提 | Playwright MCP ロード済み・テスト環境・承認済み範囲内 / TC-SEC-010 の確認操作が応答を返さずケースタイムアウト（既定 120 秒・`timeout_sec` で上書き可）を超過する |

## 分岐の根拠

SKILL.md「実行フロー」（ケースタイムアウト〔既定 120 秒〕超過は当該ケースを blocked + reason で記録し次ケースへ進む）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 8 章（タイムアウト: 超過は blocked + reason〔タイムアウト発生の旨・経過時間・最後に完了したステップ〕）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（blocked = テスト論理上のブロック・タイムアウトによるハングを含む）。

## 期待動作

- TC-SEC-010 の確認操作を実行し、応答が返らないままケースタイムアウトを超過したことを検出する
- 当該ケースを `status: blocked` + `reason`（タイムアウト発生の旨・経過時間・最後に完了したステップ）で記録する（execution-policy.md 8 章）
- `skipped`（実行手段不在）ではなく `blocked`（タイムアウトによるハング）を用いる（yaml-schema-results.md 6 章）
- blocked は `defect` を持たない（reason 必須・3 点セット不要）
- 次ケース TC-SEC-011 へ進み run 全体を止めない
- scope 全 2 件のエントリを返す
- 機微情報を扱った場合はマスクしてからエビデンス保存する
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | タイムアウトまでに取得できた部分的な記録（あれば evidence/ へ・マスク済み）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-security" / 受領 run_id / TC-SEC-010 は blocked + reason・defect なし / TC-SEC-011 は通常判定） |
| 終了状態 | TC-SEC-010 を blocked で記録し次ケースへ継続（skipped ではない） |

## 関連ケース

- case-05: MCP 未ロードによる skipped（実行手段不在との使い分け）
- case-01: 通常のヘッダ検査 fail（タイムアウトせず判定できる分岐）
