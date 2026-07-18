# case-02 未認証アクセス制御 pass

未認証状態で保護リソースへアクセスを試み、正しくログイン画面へリダイレクトされ保護コンテンツに到達できないことを確認する pass ケース。到達可否の確認（非破壊）・pass 記録を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-143000` / ケース: `[TC-SEC-002]`（観点: 認証・未認証アクセス制御, priority: high）/ アプリ情報: `https://localhost:5001`（テスト環境） |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ） |
| 前提 | 対象はテスト環境と確認済み / 承認済みケース範囲内 / 保護 URL は未認証時にログイン画面へリダイレクトされる |

## 分岐の根拠

`references/security-execution.md` 2.1（認証: 未認証アクセス制御の手順）・0.1（到達可否の確認に留める）、`${CLAUDE_PLUGIN_ROOT}/references/test-levels.md` 4.8（認証の主な確認観点）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 6 章（priority: high の pass はエビデンス必須）。

## 期待動作

- ログアウト状態（または新規セッション）で保護 URL へ `browser_navigate` し、到達可否を観察する（security-execution.md 2.1）
- 保護コンテンツに到達できず、ログイン画面へリダイレクトされることを確認して `status: pass` とする
- 到達可否の**確認**に留め、到達後のデータ操作・破壊的操作を行わない（security-execution.md 0.2）
- priority: high のため pass でもエビデンス（リダイレクト後のログイン画面スクリーンショット）を 1 件以上含める（evidence-policy.md 6 章）
- `actual` に確認結果（未認証では保護コンテンツに到達不可・ログイン画面へリダイレクト）を記述する
- 中間結果 JSON に `status: pass` / `executed_by: playwright-mcp` / `evidence` を埋めて返却する（execution-policy.md 4 章）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | リダイレクト後のログイン画面スクリーンショット（priority: high の pass エビデンス・機微情報はマスク済み）を evidence/{run_id}/{case_id}/ へ移送。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-security" / 受領 run_id / 当該ケース pass・executed_by: playwright-mcp・evidence 付き） |
| 終了状態 | 未認証で保護コンテンツに到達不可（ログイン画面へリダイレクト）のため当該ケースを pass で返却 |

## 関連ケース

- case-01: セキュリティヘッダ欠如の fail
- case-03: XSS 反射確認（無害ペイロード）
