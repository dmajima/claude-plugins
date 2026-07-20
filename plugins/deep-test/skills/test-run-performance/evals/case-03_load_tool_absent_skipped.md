# case-03 負荷ツール不在 → 多重負荷ケース skipped

多重負荷計測を要するケースがあるが、環境に外部負荷ツール（k6 / ab / Locust 等）が存在しないケース。多重負荷ケースの skipped 記録・単一セッション計測の実施継続・スコープ境界の明記を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-143000` / ケース: `[TC-PERF-003, TC-PERF-010]`（TC-PERF-003=単一応答時間 / TC-PERF-010=多重負荷スループット）/ アプリ情報: `https://localhost:5001` |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ） |
| 前提 | Playwright MCP ロード済み / `command -v k6 ab wrk locust hey vegeta` がいずれも空（負荷ツール未導入） |

## 分岐の根拠

SKILL.md「実行モード判定」の計測種別分岐、`references/performance-execution.md` 4.1（負荷ツールの検出）・4.3（スコープ境界の遵守）、`${CLAUDE_PLUGIN_ROOT}/references/test-levels.md` 7 章（多重負荷は外部ツール検出時のみ・専用負荷試験の非代替）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 2 章（条件付き動的検証: 負荷ツール検出不可 → 多重負荷ケースのみ skipped）。

## 期待動作

- Bash で負荷ツールの有無を検出する（`command -v` による存在確認のみ・実行はしない。performance-execution.md 4.1）
- いずれも未検出のため、多重負荷ケース TC-PERF-010 を `status: skipped` + `reason`（負荷ツール未検出）で返す（execution-policy.md 2 章）
- 単一セッション応答時間ケース TC-PERF-003 は通常どおり計測・判定する（performance-execution.md 4.1「単一セッション計測は実施する」）
- skipped を「pass」「問題なし」へ書き換えない（execution-policy.md 2 章）
- 「多重負荷・スループット計測は専用負荷試験の代替ではない」旨を逸脱した性能保証表現を書かない（test-levels.md 7 章 / performance-execution.md 4.3）
- skipped ケースは環境整備後の ng-only 再テスト対象になる旨と整合する（reason に実行手段不在を明記）
- scope 全 2 件のエントリを返す（execution-policy.md 3 章）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | TC-PERF-003 の計測値生データ(JSON)・スクリーンショットを evidence/{run_id}/{case_id}/ へ移送（skipped の TC-PERF-010 は該当なし）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-performance" / 受領 run_id / results 2 件〔TC-PERF-003 の判定 + TC-PERF-010 の skipped・reason〕） |
| 終了状態 | scope 全 2 件を 1 エントリずつ返却し、TC-PERF-010 は負荷ツール未検出のため skipped（reason 付き）、TC-PERF-003 は通常計測の判定で返却 |

## 関連ケース

- case-04: 負荷ツール検出時の条件付き実行（対の分岐）
- case-01: 単一セッション応答時間 pass
