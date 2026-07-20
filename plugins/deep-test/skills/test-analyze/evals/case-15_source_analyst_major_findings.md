# case-15 source-analyst が重大指摘あり（重大指摘→材料へ反映→再チェックループで収束）

source-analyst 自己チェックが**重大指摘**を返し、procedures.md 1 章フロー図の `M --重大指摘--> N[材料へ反映] --> M` の `N --> M` エッジ（反映後に自己チェックへ戻る）に入るケース。procedures.md 7 章の 3 分岐（重大 / 軽微 / 低信頼・入力不足）のうち、「**重大な指摘 → 材料（analysis.yaml / target-analysis.md）へ反映**」経路を検証する。重大指摘を材料へ反映してから**再度 source-analyst を単独起動して自己チェックに戻る再チェックループ（材料再生成ループ = Phase 2 自己チェック ⇄ Phase 3 指摘反映。反映が材料を再生成し再度自己チェックに戻る）に突入し、重大指摘が解消（収束）するまで反復してから返却**する。case-12（軽微のみ・ループ非突入）と対になる。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `対象説明=./ target-slug=orderapp-web base=<base>` |
| 起動形態 | 委譲（オーケストレータ `test` から Skill ツール経由） |
| 前提 | full で解析済みの analysis.yaml / target-analysis.md を生成済み（Phase 1 材料生成は完了）/ source-analyst が総合所見「NEEDS REVISION 相当」で**重大指摘を根拠付きで返す**（例: 公開エントリポイント〔`exposure: public`〕の取りこぼし・risk_register の `likelihood_basis` / `impact_basis` が薄い「リスク根拠の弱さ」・計測ツール無しなのに実数が入った複雑度の「捏造の疑い」・web-app なのにインタラクション能力 / セキュリティの「品質特性マッピングの欠落」）/ 併せて信頼度の低い指摘・入力不足で確認できない指摘も混在する |

## 分岐の根拠

SKILL.md「実行フロー」5（自己チェック・重大指摘を反映）・「検証」（source-analyst の自己チェックを実施し重大指摘を反映）、references/procedures.md 1 章フロー図の `M[source-analyst 自己チェック] --重大指摘--> N[材料へ反映]` および `N --> M`（反映後に自己チェックへ戻る再チェックループのエッジ）・7 章の反映表（**重大な指摘（EP / 依存 / リスク / 品質特性の抜け・弱い根拠・捏造の疑い・縮退整合の不備・責務境界の逸脱） → 材料（analysis.yaml / target-analysis.md）へ反映する** / 軽微 → 反映 or 理由付き返却 / 低信頼・入力不足 → 未確認事項として返却に記載）、`${CLAUDE_SKILL_DIR}/references/agents.md` Phase 2（自己チェック・単独起動）→ Phase 3（指摘反映・本スキルが実施）および 4 章「Phase 2 → Phase 3 は重大指摘が解消するまで繰り返してよいが、反映しない指摘は理由を付して返却の所見に残す」、`${CLAUDE_PLUGIN_ROOT}/references/agents.md` 冒頭（source-analyst は評価のみ・材料修正は起動元）。

## 期待動作

- `deep-test:source-analyst` を単独起動して自己チェックする（並列起動しない）
- 返ってきた指摘に**重大指摘があることを確認し、procedures.md 1 章フローの `N --> M`（材料へ反映 → 自己チェックへ戻る）に入る**。すなわち case-12（重大指摘なし → 返却）と異なり、**材料再生成ループ（Phase 2 自己チェック ⇄ Phase 3 指摘反映）に突入する**
- 重大指摘を **analysis.yaml / target-analysis.md に反映する**（反映は本スキルが Write で行い、source-analyst には評価のみさせ材料を修正させない = agents.md 冒頭の構造規範）。例: 取りこぼした公開 EP を `EP-{3桁}` として追記（確認できた `source_ref` のみ・捏造しない）・薄い `likelihood_basis` / `impact_basis` を根拠列挙で補強・欠落した品質特性を risk_register の `quality_characteristics` と target-analysis.md の品質特性マッピングへ追加
- **「捏造の疑い」指摘への反映は「根拠を捏造して埋める」ことではなく誠実側へ是正する**こと: 計測ツール無しで実数が入っていた複雑度は `measured: false` + `null` へ戻し（`measured: false` は維持し実測のように書かない）、確認できない事項は `open_questions` へ移す
- **反映は根拠のある指摘のみに行う**。source-analyst の指摘のうち信頼度が低い / 入力不足で確認できないものは材料へ断定反映せず、`open_questions`・返却の所見に残す（黙殺しない・捏造しない）
- 反映後、**再度 `deep-test:source-analyst` を単独起動して自己チェックに戻る**（再チェックループ）。重大指摘が解消するまで Phase 2 ⇄ Phase 3 を反復し、**収束（重大指摘が無くなる）してから検証チェックリスト → 返却へ進む**（procedures.md 1 章フローの `M -->|指摘なし/軽微のみ| O` へ抜ける）
- 解消できない指摘は無限ループにせず、反映しない理由を付して返却の所見・`open_questions` に残して収束させる（agents.md 4 章）
- source-analyst の総合所見「NEEDS REVISION 相当」は起動元の判定材料であり、**最終判定は本スキルが行う**（エージェントに総合判定・材料修正をさせない）
- 反映しても **決定はしない**: `suggested_focus` 等は `level_hint` / `technique_hint` の提案に留め、レベル / 技法 / 優先度 / ケースを確定しない（決定は test-design）
- read-only に徹し、材料 analysis.yaml / target-analysis.md のみを更新する。test-results.yaml / test-cases.yaml / test-plan.md へは書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{target-slug}/analysis.yaml` / `{target-slug}/target-analysis.md`（重大指摘を反映した**更新後**。追記した EP / 補強した risk 根拠 / 追加した品質特性を含み、捏造の疑い箇所は `measured: false` + `null` へ是正・未確認は `open_questions`）。test-results.yaml / test-cases.yaml / test-plan.md へは書き込まない |
| 標準出力（要約） | 解析結果サマリの「source-analyst 自己チェック所見」に、**反映した重大指摘と再チェックで収束した旨**・反映しなかった指摘（理由付き・open_questions）を明記する |
| 終了状態 | 重大指摘があるため材料再生成ループ（Phase 2 ⇄ Phase 3）に突入し、反映 → 再チェックを重大指摘の解消（収束）まで反復してから返却。総合判定は本スキルが行う。決定は test-design へ |

## 関連ケース

- case-12: source-analyst が軽微な指摘のみで**再生成ループに入らず返却**する分岐（本ケースの対。重大指摘ありでループに突入する側）
- case-01: full 全材料生成の一連の流れで重大指摘を反映する分岐（本ケースは反映 → 再チェックの**ループ挙動そのもの**に主眼）
- case-04 / case-06: 縮退（none / partial）時の自己チェックで縮退整合の重大指摘を反映する観点（縮退軸での重大指摘反映）
- case-11: `measured: true` の数値整合を確認させる自己チェック（本ケースの「捏造の疑い → `measured: false` へ是正」と対照的な measured 側の観点）
