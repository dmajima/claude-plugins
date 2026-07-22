# case-14 依存先ケース fail → 後続ケース blocked

`depends_on` で依存を宣言したセキュリティケースの依存先が同一 run 内で fail するケース。後続ケースを実行せず blocked + reason（依存先ケース ID とその結果）で記録することを検証する。既存 functional/scenario の同型ケース（依存元 fail → 後続 blocked）を security レベルで確認する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-web / run_id=R20260722-120000 / 対象ケース TC-SEC-001（認証セッション確立の確認。実行すると fail になる）・TC-SEC-002（depends_on: [TC-SEC-001]。認証済みセッション前提のセッション管理確認）/ 対象 URL https://localhost:5001 |
| 起動形態 | 委譲（オーケストレータ test から Skill ツール経由・MCP ゲート通過済み） |
| 前提 | MCP 利用可・対象がテスト環境・承認済みケース範囲内。TC-SEC-001 が欠陥により fail する状態 |

## 分岐の根拠

SKILL.md「実行フロー」（preconditions 確認: テストアカウント・権限準備）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md`（依存元 fail 時、後続ケースは blocked + reason で記録）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` 2 章（depends_on）・`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（blocked の意味論: 依存ケースの fail）、`${CLAUDE_SKILL_DIR}/references/security-execution.md`（観点別チェック手順・非破壊操作の境界）。

## 期待動作

- TC-SEC-001 を承認済み範囲・非破壊操作で実行して fail と判定し、`defect.extras.owasp_category` を記録して severity を severity-policy.md 4.2 で判定、defect 3 点セットを収集する
- TC-SEC-002 の実行前に depends_on を確認し、依存先（TC-SEC-001）が同一 run 内で fail であることを検出する
- TC-SEC-002 の観点別チェックを実行せず **blocked** と判定し、reason に依存先ケース ID（TC-SEC-001）とその結果（fail）を記録する
- blocked のケースに defect・severity・owasp_category を付与しない
- 依存先が fail でも後続を強行実行しない（承認範囲外の副作用・無意味な検証の量産を防ぐ）
- 対象外領域（ペネトレーション・SCA・SAST）は本ケースの主眼ではないが、依存 blocked を「問題なし」と結論しない
- scope 全件（2 エントリ: fail 1 件 + blocked 1 件）を返却する
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | TC-SEC-001 の fail 証跡（機微情報マスク済みのリクエスト/レスポンス記録・スクリーンショット）を evidence/R20260722-120000/TC-SEC-001/ へ移送・保存（TC-SEC-002 は実行しないためエビデンスなし）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-security" / 受領 run_id / results 2 件。fail エントリは owasp_category・severity 付き defect、blocked エントリは依存先 ID と結果を記した reason 付き。機微情報は生値を出さずマスク）。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 2 件を 1 エントリずつ返却（TC-SEC-001 fail / TC-SEC-002 blocked＝依存先 fail。後続の強行実行なし） |

## 関連ケース

- case-01: ヘッダ欠落による fail 処理（fail そのもの）
- case-08: タイムアウトによる blocked（blocked の別要因）
- test-run-functional case-05 / test-run-integration case-13: 他レベルの同型（依存元 fail → 後続 blocked）
