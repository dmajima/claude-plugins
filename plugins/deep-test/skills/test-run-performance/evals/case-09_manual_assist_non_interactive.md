# case-09 manual-assist ケース × 非対話モード（skipped + reason で返却）

`automation: manual-assist` の performance スコープのケースを **非対話モード**で受領した場合、人手介在ができないため実行せず、`status: skipped` + reason で返す（Playwright タイミング計測で自動実行したかのように偽装しない・実測値をでっち上げない）ことを検証する。対話モード（人手確認して human-assisted 記録）の主系は case-08 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-172000` / ケース: `[TC-PERF-012]`（`automation: manual-assist`。外部監視ダッシュボードの目視読み取り・実運用相当環境での体感応答性確認など、Playwright 計測で代替できない人手確認ケース）/ アプリ情報: `https://localhost:5001` / `--non-interactive` |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・非対話） |
| 前提 | 非対話モードのため人手確認を求められない |

## 分岐の根拠

SKILL.md「実行モード判定」の manual-assist 分岐（非対話時は skipped + reason）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 9 章（非対話既定値表: manual-assist は実行せず skipped + reason 記録）・4 章（中間結果フォーマット・scope 全件返却）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（skipped の意味論）。

## 期待動作

- 人手介在ができないため実行せず、`status: skipped` + `reason`（例: 「非対話モードのため人手確認ケースは未実施」）で返す（execution-policy.md 9 章）
- Playwright タイミング計測で自動実行したかのように偽装しない（executed_by を `playwright-mcp` と誤記しない・実測値をでっち上げない・skipped を「問題なし」に書き換えない）
- ユーザーへの手動確認依頼を行わない（非対話モード）
- scope 全件について 1 エントリ（skipped + reason）を返す
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（実行しないためエビデンスなし。test-results.yaml へも書き込まない） |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-performance" / 受領 run_id / results 1 件が skipped + reason） |
| 終了状態 | skipped + reason で返却（人手確認を求めず・実測値の捏造や自動実行への偽装をしない） |

## 関連ケース

- case-08: 同じ manual-assist ケースの対話モード（人手確認して executed_by: human-assisted で記録する主系）
- case-03: 負荷ツール未検出による skipped（実行手段不在の別要因）との対比
- case-05: MCP 未ロードによる skipped（実行手段不在のさらに別の要因）との対比
