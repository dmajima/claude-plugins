# case-05 Playwright MCP 未ロード（ブラウザ依存は skipped・curl 完結ヘッダ検査は実施）

Playwright MCP が現セッションで未ロードのケース。ブラウザ操作を要する観点のケースは skipped + reason で返し、`curl` のみで完結するヘッダ検査ケースは Bash で継続することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-166000` / ケース: `[TC-SEC-001, TC-SEC-002]`（TC-SEC-001=セキュリティヘッダ〔curl 完結可〕 / TC-SEC-002=未認証アクセス制御〔ブラウザ操作必須〕）/ アプリ情報: `https://localhost:5001`（テスト環境） |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ） |
| 前提 | `mcp__playwright__*` ツールが未ロード。対象はテスト環境・承認済み範囲内 |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/security-execution.md` 1 章（前段: Playwright MCP のロード状態を初回ブラウザ操作前に確認。未ロードなら Playwright を要する観点のケースを skipped + reason〔MCP 未ロード〕で返す。ヘッダ確認のみ curl で完結するケースは Bash で継続してよい）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 2 章（条件付き動的検証: 実行手段不在は skipped + reason）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` 4 章（未検出時は偽装せず skipped 返却）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（skipped の意味論）。

## 期待動作

- 初回ブラウザ操作前に `mcp__playwright__*` ツールの実利用可否を確認する
- **ブラウザ操作必須ケース TC-SEC-002（未認証アクセス制御）は skipped + reason（Playwright MCP 未ロード）** で返す（実行を偽装しない）
- **curl のみで完結するヘッダ検査ケース TC-SEC-001 は Bash（`curl -sk -I`）で継続実施**する（security-execution.md 1 章。ヘッダ観察は Playwright 不要）
- MCP 依存とヘッダ検査を切り分ける判断根拠を明確にする（curl で完結する観点は skipped にしない）
- skipped を「pass」「問題なし」に書き換えない
- 機微情報（Set-Cookie 等）を扱う場合はマスクしてからエビデンス保存する
- scope 全 2 件のエントリを返す
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | TC-SEC-001: curl のヘッダ観察記録（マスク済みテキスト）を evidence/ へ保存。TC-SEC-002: なし（ブラウザ操作を実行しない）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-security" / 受領 run_id / results 2 件: TC-SEC-001 は curl で判定した結果・TC-SEC-002 は skipped + reason: MCP 未ロード） |
| 終了状態 | ブラウザ依存ケースは skipped・curl 完結ケースは実施して判定を返却 |

## 関連ケース

- case-01: セキュリティヘッダ欠如 fail（curl 観察による判定）
- case-02: 未認証アクセス制御（ブラウザ操作による確認・MCP 利用可時）
- case-08: タイムアウトによる blocked（実行手段不在とは別要因）
