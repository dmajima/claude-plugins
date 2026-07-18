# case-01 セキュリティヘッダ欠如検出 fail（owasp_category 記録）

主要ページのレスポンスに HSTS（Strict-Transport-Security）等のセキュリティヘッダが設定されておらず fail となるケース。ヘッダ観察・owasp_category 記録・severity 判定を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-143000` / ケース: `[TC-SEC-001]`（観点: セキュリティヘッダ）/ アプリ情報: `https://localhost:5001`（テスト環境） |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ） |
| 前提 | 対象はテスト環境と確認済み / 承認済みケース範囲内 / レスポンスに CSP・HSTS が未設定 |

## 分岐の根拠

`references/security-execution.md` 2.4（セキュリティヘッダの確認手順・`curl -I` / `browser_network_requests`）・3 章（判定と severity）、`${CLAUDE_PLUGIN_ROOT}/references/severity-policy.md` 4.2（セキュリティヘッダ欠如の severity 目安: medium）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 4 章（defect.extras.owasp_category）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 1 章（fail 時 defect 3 点セット）。

## 期待動作

- `browser_network_requests` のレスポンスヘッダ、または Bash `curl -sk -I` で主要セキュリティヘッダの有無を観察する（読み取りのみ。security-execution.md 2.4）
- CSP・HSTS の欠如を検出し `status: fail` とする
- `defect.extras.owasp_category` に該当カテゴリ（例: A05:2021 Security Misconfiguration）を記録する（yaml-schema-results.md 4 章）
- severity を `severity-policy.md` 4.2 の OWASP 対応表（ヘッダ欠如 → medium 目安）で判定する。SSOT の基準に照らし、本ケースファイル・スキルにバンドを複製しない
- defect 3 点セット（reproduction_steps〔環境・確認手順〕/ test_data〔対象 URL・期待ヘッダ〕/ evidence〔ヘッダ観察のテキスト記録〕）を収集する（evidence-policy.md 1 章）
- ヘッダ観察のリクエスト/レスポンス記録を evidence/ へ move する（data-locations.md 5 章）
- 破壊的操作を行わない（観察のみ。security-execution.md 0.2）
- 中間結果 JSON に fail エントリを埋めて返却する（execution-policy.md 4 章）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | ヘッダ観察のリクエスト/レスポンス記録（マスク済み）・スクリーンショットを evidence/{run_id}/{case_id}/ へ移送。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-security" / 受領 run_id / 当該ケース fail・extras.owasp_category・severity 付き） |
| 終了状態 | CSP・HSTS の欠如を検出したため当該ケースを fail で返却 |

## 関連ケース

- case-02: 未認証アクセス制御が有効な pass
- case-04: 機微情報マスキング動作
