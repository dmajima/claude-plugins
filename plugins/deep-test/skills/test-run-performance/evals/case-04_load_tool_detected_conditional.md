# case-04 負荷ツール検出 → 条件付き実行

環境に外部負荷ツール（例: k6）が導入されており、多重負荷ケースを条件付きで実行するケース。負荷ツール検出・多重負荷計測の実施・スコープ境界（専用負荷試験の非代替）の遵守を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-143000` / ケース: `[TC-PERF-010]`（多重負荷: 並列 20・60 秒・対象 API）/ アプリ情報: `https://localhost:5001` |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ） |
| 前提 | Playwright MCP ロード済み / `command -v k6` が実体パスを返す（k6 導入済み） |

## 分岐の根拠

`references/performance-execution.md` 4.1（負荷ツールの検出）・4.2（多重負荷計測の実行）・4.3（スコープ境界の遵守）、`${CLAUDE_PLUGIN_ROOT}/references/test-levels.md` 7 章（条件付き多重負荷）、`${CLAUDE_PLUGIN_ROOT}/references/severity-policy.md` 4.1（エラー率・応答不能時の severity）、`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 5 章（負荷ログの evidence 移送）。

## 期待動作

- Bash で k6 を検出する（`command -v k6` が実体を返す。performance-execution.md 4.1）
- ケース定義の並列数（20）・継続時間（60 秒）・対象に従い k6 で多重負荷計測を実行する（performance-execution.md 4.2）
- 取得指標（スループット req/s・エラー率・応答時間パーセンタイル p50/p95）を記録し、実行ログ・集計結果を evidence/ へ move する（performance-execution.md 4.2 / data-locations.md 5 章）
- 実行主体・ツール名を actual に明記する（Playwright 計測部分と負荷ツール部分の切り分け。performance-execution.md 4.2）
- ケース閾値（スループット・エラー率）との比較で pass / fail を判定し、fail 時は extras に実測値・閾値を記録する
- 多重負荷を実施しても「専用負荷試験の代替」「性能保証」と表現しない（test-levels.md 7 章 / performance-execution.md 4.3）
- 中間結果 JSON にエントリを埋めて返却する（execution-policy.md 4 章）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | k6 の実行ログ・集計結果（スループット・エラー率・p50/p95）と計測値生データ(JSON)を evidence/{run_id}/{case_id}/ へ移送。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-performance" / 受領 run_id / 当該ケースの判定・actual に実行主体〔k6〕を明記、fail 時は extras.measured_value/threshold 付き） |
| 終了状態 | k6 検出により多重負荷計測を条件付き実行し、ケース閾値（スループット・エラー率）との比較結果（pass / fail）で当該ケースを返却 |

## 関連ケース

- case-03: 負荷ツール未検出時の skipped（対の分岐）
