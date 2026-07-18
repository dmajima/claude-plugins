# case-05 ケースとテストの対応付け不能（blocked / skipped の使い分け）

ランナーは検出できたが、ケースとテストの対応付けができないケース。パターン未記載（ケース定義不備）は blocked、パターンに合致するテスト不在は skipped と使い分けることを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-api / run_id=R20260717-170000 / 対象ケース TC-UNIT-001（data / steps にテスト名・パターンの記載がない）・TC-UNIT-002（test_pattern はあるが合致するテストが 0 件） |
| 起動形態 | 委譲（オーケストレータ test から Skill ツール経由） |
| 前提 | pytest 基盤あり・テストスイート自体は実行可能 |

## 分岐の根拠

references/unit-execution.md 2.1〜2.3（対応付けの根拠情報・手順・不能時の判定表）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（blocked = テスト論理上の前提不成立 / skipped = 実行手段不在）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 3 章（blocked / skipped の reason 必須）。

## 期待動作

- TC-UNIT-001（パターン未記載）は **blocked** とし、reason に「ケース定義にテスト対応付け情報がない（test-design での data / steps 補完が必要）」の趣旨を記録する
- TC-UNIT-002（合致テスト 0 件）は **skipped** とし、reason に「対象テストコード不在（パターンに合致するテストなし）」の趣旨とパターン文字列を記録する
- 両者を混同しない（ケース定義不備 = 前提不成立 → blocked / テストコード不在 = 実行手段不在 → skipped。yaml-schema-results.md 6 章の意味論に従う）
- 対応付けできないケースのために推測でテストを実行したり、無関係なテスト結果を割り当てたりしない（偽装禁止）
- 対応付け可能な他ケースが scope にあれば、それらの実行は通常どおり継続する
- scope 全件について 1 エントリずつ返却する

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（scope の両ケースとも対応付け不能で実行せず、エビデンス移送も発生しない）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-unit" / 受領 run_id / results 2 件・各エントリに使い分けの根拠を記した reason 付き）を 1 コードブロックで返却。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 2 件を 1 エントリずつ返却（TC-UNIT-001 blocked＝ケース定義不備 / TC-UNIT-002 skipped＝合致テスト不在。推測での実行・結果割り当てなし） |

## 関連ケース

- case-03: ランナー自体が不在（scope 全件 skipped）
- case-01: 対応付け成功（pass の分岐）
