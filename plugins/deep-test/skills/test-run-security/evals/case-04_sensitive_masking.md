# case-04 機微情報マスキング動作

セッション管理チェックでセッション Cookie 値や Authorization ヘッダを観察する際、機微情報をエビデンス保管時・返却データにマスクして扱うケース。マスク形式の適用・生値の非記載を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-143000` / ケース: `[TC-SEC-004]`（観点: セッション管理・Cookie 属性）/ アプリ情報: `https://localhost:5001`（テスト環境） |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ） |
| 前提 | 対象はテスト環境と確認済み / 承認済みケース範囲内 / レスポンスの Set-Cookie にセッション ID・トークンが含まれる |

## 分岐の根拠

`references/security-execution.md` 5 章（機微情報マスキング手順）・2.2（セッション管理・Cookie 属性）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 5 章（マスク形式・対象・適用タイミング）、SKILL.md「重要な制約」（reason / actual / チャット出力に生値を書かない）。

## 期待動作

- Cookie 属性（Secure / HttpOnly / SameSite）の有無を観察する（security-execution.md 2.2）
- セッション ID・トークン・Authorization ヘッダ値等の機微情報を、テキストエビデンス**保存前に**マスク形式（9 文字以上=先頭4+`****`+末尾4 / 8 文字以下=`********`）へ置換する（evidence-policy.md 5.1 / security-execution.md 5 章）
- `actual` / `reason` / `defect` にマスク値のみを記載し、生値を書かない（SKILL.md「重要な制約」）
- 中間結果 JSON の返却時点で既にマスク済みの値のみをオーケストレータへ渡す（security-execution.md 5 章）
- マスクにより再現に必要な情報が欠ける場合は「値の取得方法・格納場所」を reproduction_steps に記載する（evidence-policy.md 5.3）
- Cookie 属性に欠如（例: HttpOnly 未設定）があれば fail とし、owasp_category を記録する（severity は severity-policy.md 4.2）。属性が適切なら pass とし actual に確認結果（マスク値）を記述する
- スクリーンショットに機微情報が表示される手順を避ける設計にする（security-execution.md 5 章）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | Cookie 属性観察のリクエスト/レスポンス記録・スクリーンショット（セッション ID・トークン等の機微情報は保存前にマスク済み）を evidence/{run_id}/{case_id}/ へ移送。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-security" / 受領 run_id / 当該ケースの判定。actual / reason / defect はマスク値のみで生値を含まない） |
| 終了状態 | Cookie 属性の判定結果（欠如あり fail〔owasp_category 付き〕/ 適切なら pass）で当該ケースを返却 |

## 関連ケース

- case-01: セキュリティヘッダ欠如 fail
- case-03: XSS 反射確認（無害ペイロード）
