# case-02 シナリオ途中 fail → 後続 blocked（system）

業務シナリオの途中ステップ（受注確定）が失敗し、当該ケースが fail となるケース。以降のステップ打ち切り・到達ステップの actual 記録・依存する後続ケースの blocked を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-143000` / ケース: `[TC-SYS-002, TC-SYS-003]`（TC-SYS-003 は `depends_on: [TC-SYS-002]`）/ アプリ情報: `https://localhost:5001` |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ） |
| 前提 | Playwright MCP ロード済み / TC-SYS-002 のステップ 4（受注確定）でエラーが発生する |

## 分岐の根拠

`references/scenario-execution.md` 3 章（シナリオ途中 fail 時の後続判断）: 3.1（同一ケース内の以降ステップ打ち切り・到達ステップの actual 記録）/ 3.2（depends_on による後続ケースの blocked）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（fail と blocked の使い分け）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 1 章（fail 時 defect 3 点セット必須）。

## 期待動作

- TC-SYS-002 のステップ 4 でエラーを検出したら、当該ケースを `status: fail` とし、以降のステップ（ステップ 5 以降）を打ち切る（`references/scenario-execution.md` 3.1）
- `actual` に到達ステップを明記する（例: 「ステップ 4 の受注確定でエラー。ステップ 5 以降は未到達（先行 fail のため）」）
- 失敗時の追加証跡（アクセシビリティスナップショット・コンソールログ）を取得し evidence/ へ move、defect.evidence に含める（execution-policy.md 7 章）
- defect 3 点セット（reproduction_steps〔環境情報含む〕/ test_data〔入力値・期待値・実際値〕/ evidence）を収集する（evidence-policy.md 1 章）
- severity を `${CLAUDE_PLUGIN_ROOT}/references/severity-policy.md` の基準で判定する（業務停止相当なら高い側）
- TC-SYS-003 は `depends_on` 先の TC-SYS-002 が fail のため `status: blocked` + `reason`（依存元 TC-SYS-002 が fail のため実行不能）とし、`defect` は付与しない（scenario-execution.md 3.2 / yaml-schema-results.md 6 章）
- scope 全 2 件のエントリを返す（execution-policy.md 3 章 scope 全件返却）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `evidence/R20260717-143000/TC-SYS-002/` 配下にスクリーンショットと失敗時の追加証跡（アクセシビリティスナップショット・コンソールログ。defect 3 点セットの evidence として参照される）。未実行の TC-SYS-003 はなし。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-scenario" / 受領 run_id / results 2 件・TC-SYS-002 に defect 3 点セット付き）。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 2 件を 1 エントリずつ返却。TC-SYS-002 は fail（actual に到達ステップを明記・severity 付与）、TC-SYS-003 は blocked + reason（依存元 fail・defect なし） |

## 関連ケース

- case-01: シナリオ通し pass（正常分岐）
- case-03: UAT 観点の fail（ユーザー影響記載）
