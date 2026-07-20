# case-05 Playwright MCP 未ロード → skipped（単一計測ケース・多重負荷ケース両方）

Playwright MCP が現セッションで未ロードのケース。単一セッション応答時間計測ケースも多重負荷ケースも、実行を偽装せず skipped + reason で返すことを検証する（負荷ツール未検出とは別要因）。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-164000` / ケース: `[TC-PERF-003, TC-PERF-010]`（TC-PERF-003=単一応答時間 / TC-PERF-010=多重負荷スループット）/ アプリ情報: `https://localhost:5001` |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ） |
| 前提 | `mcp__playwright__*` ツールが未ロード（MCP ゲート通過後のセッション喪失・直接起動などの理由）。本スキルの計測は Playwright タイミング計測を前提とする |

## 分岐の根拠

SKILL.md「前提」（未ロード検出時は偽装せず skipped で返却）・「重要な制約」（Playwright MCP 未ロード検出時は偽装せず skipped + reason で返却する）、`${CLAUDE_SKILL_DIR}/references/performance-execution.md` 1 章（計測は browser_navigate / browser_evaluate に依存）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 2 章（条件付き動的検証: 実行手段不在は skipped + reason）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` 4 章（未検出時は偽装せず skipped 返却）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（skipped の意味論）。

## 期待動作

- 初回ブラウザ操作前に `mcp__playwright__*` ツールの実利用可否を確認する（登録の有無だけで利用可と判定しない）
- 未ロードを検出したら、**単一セッション応答時間ケース TC-PERF-003 を skipped + reason（Playwright MCP 未ロード）** で返す（本スキルの計測が Playwright タイミング計測に依存するため計測不能）
- **多重負荷ケース TC-PERF-010 も skipped + reason（Playwright MCP 未ロード）** で返す。この reason は「負荷ツール未検出」（case-03）とは**別要因**であることを明示する
- 計測を実行したかのように偽装しない（実測値をでっち上げない・skipped を「pass」「問題なし」に書き換えない）
- scope 全 2 件のエントリを返す（execution-policy.md 3 章）
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（計測を実行しないため計測値生データ・スクリーンショットの生成なし）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-performance" / 受領 run_id / results 2 件すべて skipped + reason: MCP 未ロード）。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 2 件を skipped で返却（reason は負荷ツール未検出ではなく MCP 未ロード） |

## 関連ケース

- case-01: MCP 利用可の単一セッション応答時間 pass
- case-03: 負荷ツール未検出による多重負荷ケース skipped（skipped の別要因との対比）
- case-06: 単独起動での必須入力欠落
