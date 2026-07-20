# case-03 no-op（unit のみ / 非 web / 材料なし＝SUT へ書き込まず空 fixtures.yaml + 理由）

再現可能 Playwright 基盤が有効でない対象（純粋なライブラリ / CLI・見込みが unit テストのみ・認証も外部依存もなし）に対し、SUT に**何も書かず**空マニフェスト（`fixtures: []`）＋判定理由を返して正常終了する非破壊 no-op を検証する。既存の探索的 MCP フロー（fixture なし）を壊さないことが目的。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=calc-lib project=./ base=<base> --non-interactive` |
| 起動形態 | 委譲（オーケストレータ `test` の Phase 1.6）/ 単独起動でも同一挙動 |
| 前提 | `analysis.yaml` 存在（`meta.target_type: library`・UI 経路なし・`entry_points` は public-function のみで認証なし・`external_dependencies` なし）。見込みは unit テストのみ |

## 分岐の根拠

SKILL.md「実行フロー」3（要否判定＝不要 → 空 fixtures.yaml + 理由で正常終了）・「重要な制約」（no-op 条件: 非 web / unit のみ / 認証も外部依存もなしなら SUT に何も書かず空 fixtures.yaml + 理由）、`${CLAUDE_SKILL_DIR}/references/fixture-procedures.md` 4 章（fixture 要否判定の no-op 分岐・迷う場合は「作らない」を既定）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md` 0 章（playwright-test は fixture 基盤があるケースのオプトイン経路であり既定の探索的フローを崩さない）。test-fixture 側の自己限定（＝空 fixtures.yaml で正常終了する非破壊パターン）は前掲 fixture-procedures.md 4 章と SKILL.md「重要な制約」に規定。

## 期待動作

- `analysis.yaml` を消費し、`meta.target_type: library`・認証 EP なし・外部依存なしを検出する
- fixture 要否を「不要」と判定する（非 web・unit のみ・認証も外部依存もなし）
- **SUT に一切書き込まない**（`playwright.config.ts` / fixtures / auth.setup.ts / seed を生成しない）
- `{base}/{target-slug}/fixtures.yaml` を `fixtures: []` として出力し、`meta` に `analysis_consumed: true` と判定理由（例: 「target_type=library・認証/外部依存なしのため Playwright フィクスチャ基盤は不要」）を残す
- 憶測でフィクスチャを生成しない（過剰生成を避ける・既存 MCP フローを壊さない）
- 返却に「フィクスチャ基盤は不要と判定（no-op）」の旨と理由を含める。次フェーズ（test-design）は fixtures.yaml が空でも Phase 2 に直行できる
- test-results.yaml / test-cases.yaml / analysis.yaml へは書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{base}/{target-slug}/fixtures.yaml`（`fixtures: []` + 判定理由）のみ。SUT テストコードは生成しない。test-results.yaml / test-cases.yaml / analysis.yaml へは書き込まない |
| 標準出力（要約） | フィクスチャ構築結果サマリ（判定=no-op〔理由付き〕・type 別件数は全 0・SUT テストコードなし・次フェーズは fixtures.yaml 空でも test-design へ直行可能な旨） |
| 終了状態 | SUT へ書き込まず空 fixtures.yaml + 理由を出力して正常終了（エラーではない・非破壊 no-op） |

## 関連ケース

- case-01: fixture 有効（web-app・認証/外部依存あり）で新規生成する対
- case-04: 非対話の自動進行（本ケースも非対話だが主軸は no-op 判定）
- case-05: analysis.yaml 欠落時の軽量補完（材料なしでも補完して判定する対比）
