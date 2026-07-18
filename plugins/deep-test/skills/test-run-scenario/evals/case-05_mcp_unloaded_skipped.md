# case-05 Playwright MCP 未ロード（skipped + reason）

初回ブラウザ操作前に Playwright MCP が現セッションで未ロードであることを検出するケース。実行を偽装せず scope 全件を skipped + reason で返却することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-170000` / ケース: `[TC-SYS-001, TC-UAT-001]` / アプリ情報: `https://localhost:5001` |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ） |
| 前提 | 何らかの理由で `mcp__playwright__*` ツールが現セッションに未ロード（MCP ゲート通過後にセッション状態が変化した等） |

## 分岐の根拠

`references/scenario-execution.md` 1 章（前段: 初回ブラウザ操作前の MCP ロード確認）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 2 章（条件付き動的検証: 実行手段不在時は skipped + reason）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` 4 章（実行スキルは未ロード検出時に偽装せず skipped + reason で返却）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（skipped と blocked の使い分け）。

## 期待動作

- 初回ブラウザ操作の前に Playwright MCP のロード状態を確認する（scenario-execution.md 1 章）
- 未ロードを検出したら、ブラウザ操作を試行せず（実行を偽装せず）、scope の全ケースを `status: skipped` + `reason`（Playwright MCP 未ロード）で返却する（execution-policy.md 2 章 / playwright-mcp.md 4 章）
- `blocked`（論理ブロック）ではなく `skipped`（実行手段不在）を用いる（yaml-schema-results.md 6 章）
- skipped ケースは環境整備後に ng-only 再テストの対象になる旨と整合する（reason に実行手段不在を明記。retest-policy.md）
- scope 全 2 件のエントリを返す（execution-policy.md 3 章）
- 「pass」「問題なし」へ書き換えない（execution-policy.md 2 章）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（ブラウザ操作を実行しないためエビデンス生成なし）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-scenario" / 受領 run_id / results 全 2 件 skipped + reason: Playwright MCP 未ロード）。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 2 件を 1 エントリずつ skipped で返却（偽装せず reason 付き。blocked ではなく skipped を用いる） |

## 関連ケース

- case-04: 中断による blocked（論理ブロック・実行手段不在との対比）
- case-01: MCP ロード済みの正常実行
