# case-03 UAT 観点指摘（fail + ユーザー影響記載）

受入観点（uat レベル）のシナリオで、エラーメッセージが内部例外の生表示となっており業務担当者が回復行動を取れない問題を検出するケース。UAT 観点チェックリストの適用・ユーザー影響の明記・受入判断を人間に委ねる位置付けの遵守を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-150000` / ケース: `[TC-UAT-001]`（level: uat, priority: high）/ アプリ情報: `https://localhost:5001` |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ） |
| 前提 | Playwright MCP ロード済み / システムテストレベルは通過済み / 受注登録で不正値入力時に内部例外メッセージが表示される |

## 分岐の根拠

`references/scenario-execution.md` 4 章（UAT 観点チェックリスト: エラーメッセージの妥当性・業務データでの動作）、SKILL.md「実行モード判定」の uat 文脈分岐、`${CLAUDE_PLUGIN_ROOT}/references/test-levels.md` 4.6（UAT の主な確認観点）・6 章（UAT 免責）、`${CLAUDE_PLUGIN_ROOT}/references/severity-policy.md`（本番影響度での判定）。

## 期待動作

- system の確認に加え、UAT 観点チェックリスト（導線・エラーメッセージ妥当性・業務データでの成立性・帳票）を適用する（`references/scenario-execution.md` 4 章）
- エラー時に内部例外が生表示され、業務担当者が原因・次の行動を判断できない点を `status: fail` とする（回復不能な不親切メッセージ）
- `actual` と `defect.reproduction_steps` に**ユーザー影響**（どの業務担当者のどの業務がどう困るか）を明記する（scenario-execution.md 4 章）
- severity は本番影響度で判定し、「使いにくい」だけの過大評価をしない（severity-policy.md）
- defect 3 点セットを収集し、エビデンスに該当画面のスクリーンショットを含める。機微情報があればマスキング配慮する（evidence-policy.md 5 章）
- **UAT の結果を「受入完了」と結論しない**。検証支援として結果・エビデンスを提示するに留め、サインオフは人間に委ねる旨を逸脱しない（test-levels.md 6 章 / SKILL.md「重要な制約」）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `evidence/R20260717-150000/TC-UAT-001/` 配下に該当画面のスクリーンショット（defect 3 点セットの evidence として参照される。機微情報はマスキング配慮）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-scenario" / 受領 run_id / results 1 件・defect 3 点セット付き）。「引き渡し（中間結果 JSON 返却）」に準拠し、特記事項として受入判断（サインオフ）は人間に委ねる旨を添える |
| 終了状態 | scope 全 1 件を 1 エントリずつ返却し、TC-UAT-001 は fail（actual / defect にユーザー影響を明記・severity は本番影響度で判定。「受入完了」とは結論しない） |

## 関連ケース

- case-01: system の正常シナリオ
- case-02: system の途中 fail
