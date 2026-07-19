# case-09 fixture-architect が軽微な指摘のみ（重大指摘なし・反映 or 理由付き返却・再ループ非突入）

fixture-architect 自己チェックが重大指摘を返さず、軽微な指摘・提案のみを返すケース。`fixture-procedures.md` 8 章の 3 分岐（重大 / 軽微 / 低信頼・入力不足）のうち、既存ケース（case-01 等の重大指摘反映）で未検証の「軽微のみ」経路を検証する。軽微な指摘のみのため**成果物の再生成ループ（Phase 2 自己チェック ⇄ Phase 3 指摘反映の反復）に入らずに返却**し、軽微指摘は反映するか反映しない理由を付して返却の所見に残す（黙殺しない）。case-10（重大指摘・ループ突入）と対になる。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=orderapp-web project=./ base=<base>` |
| 起動形態 | 委譲（オーケストレータ `test` の Phase 1.6）/ 単独起動でも同一挙動 |
| 前提 | web-app・`analysis.yaml` 消費済みで認証/モック/base を生成済み（Phase 1 完了）/ fixture-architect が総合所見「PASS 相当」で軽微な指摘（例: fixture の `provides` 表現改善・任意の `usage` コメント追記提案・命名の一貫性提案）のみを返す / 重大指摘（書き込み境界の逸脱・認証情報のハードコード・責務分離の崩れ・再利用性の欠如・存在しない依存）はなし |

## 分岐の根拠

SKILL.md「実行フロー」7（自己チェック・重大指摘を反映）・「検証」（fixture-architect の自己チェックを実施し重大指摘を反映）、`${CLAUDE_SKILL_DIR}/references/fixture-procedures.md` 1 章フロー（`L[fixture-architect 自己チェック] --指摘なし/軽微のみ--> N[検証チェックリスト → 返却]`）・8 章の反映表（重大 → 成果物へ反映 / 軽微な指摘・提案 → 反映するか反映しない理由を付して返却の所見に残す / 信頼度の低い指摘・入力不足 → 未確認事項・所見として返却に記載〔黙殺しない〕）、`${CLAUDE_SKILL_DIR}/references/agents.md` Phase 2（自己チェック・単独起動）→ Phase 3（指摘反映は本スキルの責務・反映不要は理由を所見に残す）・4 章（重大指摘が解消するまで反復してよいが反映しない指摘は理由を所見に残す）、`${CLAUDE_PLUGIN_ROOT}/references/agents.md` 冒頭（fixture-architect は評価のみ・成果物修正は起動元）。

## 期待動作

- `deep-test:fixture-architect` を**単独起動**して自己チェックする（軽微のみでも自己チェック自体は省略しない・並列起動しない）
- 返ってきた指摘に重大指摘が無いことを確認し、**成果物の再生成ループ（Phase 2 ⇄ Phase 3 の反復）に入らずに返却**へ進む（fixture-procedures.md 1 章フローの「指摘なし/軽微のみ → 返却」）
- 軽微な指摘・提案は、(a) 成果物（`fixtures.yaml` / SUT テストコード）へ反映する か (b) 反映しない場合は理由を付して返却の所見に残す のいずれかとする（黙殺しない）
- fixture-architect の総合所見「PASS 相当」は起動元の判定材料とし、**最終判定は本スキルが行う**（エージェントに総合判定・成果物修正をさせない）
- 反映する場合も修正は本スキルが Write/Edit で行い、fixture-architect には修正させない（評価のみ。agents.md 冒頭の構造規範）
- 低信頼・入力不足による未確認は「問題なし」と書かず未確認事項・所見に残す
- 成果物の内容（認証/モック/base の各 fixture・`fixtures.yaml`）自体は case-01 と同等に生成済みで、本ケースの主眼は自己チェック結果の取り扱い分岐にある
- **決定をしない**: ケースの `fixtures:` 参照・`automation: playwright-test` の選定・レベル/技法/優先度は test-design の専有（本ケースでも確定しない）
- **書き込み境界**を維持: SUT テストディレクトリ + `fixtures.yaml` のみ。`test-results.yaml` / `test-cases.yaml` / `analysis.yaml` へは書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{base}/{target-slug}/fixtures.yaml` / SUT テストコード（軽微指摘を反映した場合は反映後・反映しない場合は生成時のまま）。プロダクションコード・test-results.yaml / test-cases.yaml / analysis.yaml への変更なし |
| 標準出力（要約） | フィクスチャ構築結果サマリの「fixture-architect 自己チェック所見」に、重大指摘なし・軽微指摘の反映済み / 反映不要と判断した指摘（理由付き）を明記する |
| 終了状態 | 重大指摘が無いため再生成ループに入らず、軽微指摘を反映 or 理由付きで所見に残して返却。総合判定は本スキルが行う。決定は test-design へ |

## 関連ケース

- case-10: fixture-architect が重大指摘を返し成果物へ反映 → 再チェックループに突入する分岐（本ケースの対）
- case-01: 新規生成の一連の流れで fixture-architect 自己チェックを行う（本ケースは軽微のみの取り扱いに主眼）
- case-06: 書き込み境界・ハードコードを fixture-architect に重点評価させる観点（本ケースは重大指摘が出なかった側）
