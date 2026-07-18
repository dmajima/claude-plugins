# case-12 source-analyst が軽微な指摘のみ（重大指摘なし・反映 or 理由付き返却）

source-analyst 自己チェックが重大指摘を返さず、軽微な指摘・提案のみを返すケース。procedures.md 7 章の 3 分岐（重大 / 軽微 / 低信頼・入力不足）のうち、既存ケース（case-01 等の重大指摘反映）で未検証の「軽微のみ」経路を検証する。軽微な指摘のみのため**材料の再生成ループ（Phase 2 と Phase 3 の反復）に入らずに返却**し、軽微指摘は反映するか反映しない理由を付して返却の所見に残す（黙殺しない）。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `対象説明=./ target-slug=orderapp-web base=<base>` |
| 起動形態 | 委譲（オーケストレータ `test` から Skill ツール経由） |
| 前提 | full で解析済みの analysis.yaml / target-analysis.md を生成済み / source-analyst が総合所見「PASS 相当」で軽微な指摘（例: `rationale` の表現改善・任意項目 `seam_suggestion` の追記提案）のみを返す / 重大指摘（EP / 依存 / リスク / 品質特性の抜け・弱い根拠・捏造の疑い・縮退整合の不備・責務境界の逸脱）はなし |

## 分岐の根拠

SKILL.md「実行フロー」5（自己チェック・重大指摘を反映）・「検証」（source-analyst の自己チェックを実施し重大指摘を反映）、references/procedures.md 1 章フロー（`指摘なし/軽微のみ → 検証チェックリスト → 返却`）・7 章の反映表（重大な指摘 → 材料へ反映 / 軽微な指摘・提案 → 反映するか反映しない理由を付して返却の所見に残す / 信頼度の低い指摘・入力不足 → 未確認事項として返却に記載〔黙殺しない〕）、`${CLAUDE_PLUGIN_ROOT}/references/agents.md` 冒頭（source-analyst は評価のみ・材料修正は起動元）、`${CLAUDE_SKILL_DIR}/references/agents.md` Phase 3（指摘反映は本スキルの責務・反映不要は理由を所見に残す）。

## 期待動作

- `deep-test:source-analyst` を単独起動して自己チェックする（軽微のみでも自己チェック自体は省略しない）
- 返ってきた指摘に重大指摘が無いことを確認し、**材料の再生成ループ（Phase 2 と Phase 3 の反復）に入らずに返却**へ進む（procedures.md 1 章フローの「指摘なし/軽微のみ → 返却」）
- 軽微な指摘・提案は、(a) 材料へ反映する か (b) 反映しない場合は理由を付して返却の所見に残す のいずれかとする（黙殺しない）
- source-analyst の総合所見「PASS 相当」は起動元の判定材料とし、**最終判定は本スキルが行う**（エージェントに総合判定・材料修正をさせない）
- 反映する場合も修正は本スキルが Write で行い、source-analyst には修正させない（評価のみ。agents.md 冒頭の構造規範）
- 低信頼・入力不足による未確認は「問題なし」と書かず未確認事項（`open_questions` / 返却の所見）に残す
- 材料の内容（EP / hotspots / risk 等）自体は case-01 と同等に生成済みで、本ケースの主眼は自己チェック結果の取り扱い分岐にある
- read-only に徹し test-results.yaml / test-cases.yaml / test-plan.md へ書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{target-slug}/analysis.yaml` / `{target-slug}/target-analysis.md`（軽微指摘を反映した場合は反映後・反映しない場合は生成時のまま）。test-results.yaml / test-cases.yaml / test-plan.md へは書き込まない |
| 標準出力（要約） | 解析結果サマリの「source-analyst 自己チェック所見」に、重大指摘なし・軽微指摘の反映済み / 反映不要と判断した指摘（理由付き）を明記する |
| 終了状態 | 重大指摘が無いため再生成ループに入らず、軽微指摘を反映 or 理由付きで所見に残して返却。総合判定は本スキルが行う |

## 関連ケース

- case-01: source-analyst の重大指摘を材料へ反映する分岐（本ケースは重大指摘なしの側）
- case-04: 縮退整合を source-analyst に確認させる分岐（縮退時の自己チェック観点）
- case-06: partial 縮退整合の自己チェック（縮退時の観点）
