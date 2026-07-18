# case-03 IT-b fail（マスク済み API レスポンス証跡）

外部結合（IT-b）のケースで、外部 IF の呼び出し結果が画面・データに正しく反映されず fail となるケース。API 補助確認による裏取りと、マスク済み API レスポンスを含む defect 3 点セットの収集を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-web / run_id=R20260717-180000 / 対象ケース TC-ITB-003（外部在庫 API の応答値が画面の在庫数表示に反映されることの検証）/ 対象 URL・外部接続先情報 |
| 起動形態 | 委譲（オーケストレータ test から Skill ツール経由・MCP ゲート通過済み） |
| 前提 | MCP 利用可・外部テスト用エンドポイント疎通可。外部 API は正しい値を返すが、画面表示への反映に欠陥がある状態 |

## 分岐の根拠

SKILL.md「実行フロー」手順 3（API 補助確認）・手順 5（fail 時）・「検証（チェックリスト）」（マスク確認）、references/integration-execution.md 2.2（連携確認）・4 章（API 補助確認・マスキング手順）・5 章（エビデンス）・7 章（defect の組み立て）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 1 章（3 点セット）・5 章（マスク形式・対象）、`${CLAUDE_PLUGIN_ROOT}/references/severity-policy.md`（判定フロー）。

## 期待動作

- 画面経由の確認（browser_snapshot）で期待値と実際の表示の不一致を検出する
- 原因の切り分けとして curl による API 直接確認を実施し（`--max-time` 設定・一時出力はセッション作業領域の workspace/tmp/）、外部 API の応答自体は正しいことを裏取りする
- API レスポンスを機微情報マスキング（sed 等で置換 → Grep でマスク漏れ確認）してから `evidence/{run_id}/TC-ITB-003/93_api-response.json` 等として保存する
- fail 確定直後に defect 3 点セットをその場で収集する:
  - reproduction_steps: 環境情報（OS・ブラウザ・対象 URL・外部接続先）を先頭にした完全な操作列
  - test_data: リクエスト内容（マスク済み）・期待値（API 応答値が画面に表示される）・実際値（実表示）
  - evidence: 画面スクリーンショット + マスク済み API レスポンスの相対パス（実在するファイル）
- actual に「API 応答は正常・画面反映が不正」という切り分け結果を記録する（API 証跡が defect の根拠になる）
- defect.severity を severity-policy.md の判定フローで付与する
- 認証情報・トークンのフル値を JSON・エビデンス・チャット出力に含めない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `evidence/R20260717-180000/TC-ITB-003/` 配下に画面スクリーンショットとマスク済み API レスポンス（`93_api-response.json` 等・Grep でマスク漏れ確認済み）。fail のため defect 3 点セットの evidence として参照される。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-integration" / 受領 run_id / results 1 件・defect 3 点セット付き）。「引き渡し（中間結果 JSON 返却）」に準拠し、認証情報等のフル値を含めない |
| 終了状態 | scope 全 1 件を 1 エントリずつ返却し、TC-ITB-003 は fail（actual に「API 応答は正常・画面反映が不正」の切り分けを記録、severity 付与） |

## 関連ケース

- case-02: 外部接続不可（スタブ判断の分岐）
- case-05: 認証が必要な API 確認（credentials 案内）
