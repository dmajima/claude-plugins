# case-01 業務シナリオ通し pass（system）

複数機能を跨ぐ業務シナリオ（ログイン → 受注登録 → 一覧確認 → ログアウト）を最初から最後まで通しで実行し、全ステップが期待どおりで pass となるケース。通し実行・エビデンス取得・pass 記録を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-143000` / ケース: `[TC-SYS-001]`（priority: high）/ アプリ情報: `https://localhost:5001` |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ） |
| 前提 | Playwright MCP ロード済み / テスト環境到達可能 / TC-SYS-001 は review_status: approved |

## 分岐の根拠

SKILL.md「実行フロー」（preconditions → steps 実行・エビデンス取得 → expected 照合 → postconditions → pass 記録）、`references/scenario-execution.md` 2 章（1 シナリオの実行手順）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 7 章（エビデンス自動収集）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 6 章（priority: high の pass はエビデンス必須）。

## 期待動作

- ログイン → 受注登録 → 一覧確認 → ログアウトの各ステップを順に実行し、途中で分割しない（SKILL.md「責務」）
- 各ステップ直後にスクリーンショットを取得し `evidence/R20260717-143000/TC-SYS-001/` へ move する（`references/scenario-execution.md` 2.2 / data-locations.md 5 章）
- priority: high のため pass でも主要ステップのスクリーンショットを 1 件以上 evidence に含める（evidence-policy.md 6 章）
- `actual` にシナリオ完遂状況（全ステップ到達・完了）を記録する（test-levels.md system 出口基準）
- postconditions（投入した受注データ削除・ログアウト）を実行し共有環境を汚染しない
- 中間結果 JSON に `status: pass` / `executed_by: playwright-mcp` / `duration_sec` / `evidence` を埋めて返却する（execution-policy.md 4 章）
- `test-results.yaml` を直接編集しない（返却のみ。SKILL.md「重要な制約」）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `evidence/R20260717-143000/TC-SYS-001/` 配下に各ステップ直後のスクリーンショット（priority: high のため pass でも 1 件以上を evidence に含める）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-scenario" / 受領 run_id / results 1 件・executed_by: "playwright-mcp" / duration_sec / evidence 付き）。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 1 件を 1 エントリずつ返却し、TC-SYS-001 は pass（actual にシナリオ完遂状況を記録・postconditions 実行済み） |

## 関連ケース

- case-02: シナリオ途中 fail → 後続 blocked（fail 分岐）
- case-04: 長大シナリオの中断（進行状況記録）
