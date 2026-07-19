# case-10 fixture-architect が重大な指摘あり（重大指摘→設計に反映→再チェックループで収束・書込境界/認証ハードコードの是正例）

fixture-architect 自己チェックが**重大指摘**を返し、`fixture-procedures.md` 1 章フロー図の `L[fixture-architect 自己チェック] --重大指摘--> M[成果物へ反映] --> L`（反映後に自己チェックへ戻る）に入るケース。8 章の 3 分岐（重大 / 軽微 / 低信頼・入力不足）のうち「**重大な指摘 → 成果物（fixtures.yaml / SUT テストコード）へ反映**」経路を検証する。重大指摘（書き込み境界の逸脱・認証情報のハードコード等）をフィクスチャ設計へ反映してから**再度 fixture-architect を単独起動して自己チェックに戻る再チェックループ（Phase 2 ⇄ Phase 3）に突入し、重大指摘が解消（収束）するまで反復してから確定・返却**する。case-09（軽微のみ・ループ非突入）と対になる。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=orderapp-web project=./ base=<base>` |
| 起動形態 | 委譲（オーケストレータ `test` の Phase 1.6）/ 単独起動でも同一挙動 |
| 前提 | web-app・`analysis.yaml` 消費済みで認証/モック/base を生成済み（Phase 1 完了）/ fixture-architect が総合所見「NEEDS REVISION 相当」で**重大指摘を根拠付きで返す**（例: storageState 出力先を SUT プロダクションコード配下に書く**書き込み境界の逸脱**・`auth.setup.ts` に実ユーザー名/パスワードを直書きした**認証情報のハードコード**・auth と mock を 1 fixture に混載した**責務分離の崩れ**・`analysis.yaml` に根拠の無い外部依存をモックした**存在しない依存**）/ 併せて信頼度の低い指摘・入力不足で確認できない指摘も混在する |

## 分岐の根拠

SKILL.md「実行フロー」7（自己チェック・重大指摘を反映）・「検証」（fixture-architect の自己チェックを実施し重大指摘を反映）・「重要な制約」（書き込み境界・認証情報のハードコード禁止）、`${CLAUDE_SKILL_DIR}/references/fixture-procedures.md` 1 章フロー図の `L[fixture-architect 自己チェック] --重大指摘--> M[成果物へ反映]` および `M --> L`（反映後に自己チェックへ戻る再チェックループのエッジ）・8 章の反映表（**重大な指摘〔書き込み境界の逸脱・認証情報のハードコード・責務分離の崩れ・再利用性の欠如・存在しない依存〕→ 成果物へ反映** / 軽微 → 反映 or 理由付き返却 / 低信頼・入力不足 → 未確認事項として返却に記載）・6.1 章（書き込み境界）、`${CLAUDE_SKILL_DIR}/references/agents.md` Phase 2 → Phase 3・4 章「Phase 2 → Phase 3 は重大指摘が解消するまで繰り返してよいが、反映しない指摘は理由を付して返却の所見に残す」、`${CLAUDE_PLUGIN_ROOT}/references/agents.md` 冒頭（fixture-architect は評価のみ・成果物修正は起動元）、credentials-management ルール（MANDATORY・認証情報の実値をハードコードしない）。

## 期待動作

- `deep-test:fixture-architect` を単独起動して自己チェックする（並列起動しない）
- 返ってきた指摘に**重大指摘があることを確認し、fixture-procedures.md 1 章フローの `M --> L`（成果物へ反映 → 自己チェックへ戻る）に入る**。すなわち case-09（重大指摘なし → 返却）と異なり、**再生成ループ（Phase 2 ⇄ Phase 3）に突入する**
- 重大指摘を **`fixtures.yaml` / SUT テストコードに反映する**（反映は本スキルが Write/Edit で行い、fixture-architect には評価のみさせ成果物を修正させない = agents.md 冒頭の構造規範）。是正例:
  - **書き込み境界の逸脱**: storageState 出力先や生成物を SUT テストディレクトリ配下（`{project}/{test_root}/`・`playwright.config.ts`）へ是正し、プロダクションコード配下への書き込みを撤回する
  - **認証情報のハードコード**: `auth.setup.ts` の実ユーザー名/パスワードを `process.env.*`・credentials-manager 経由の取得コードに置換し、storageState 出力先（`tests/.auth/`）の `.gitignore` 追記を提案する
  - **責務分離の崩れ**: auth と mock を別 fixture（`auth.fixture.ts` / `*.fixture.ts`）へ分離する
  - **存在しない依存**: `analysis.yaml` に根拠の無いモックを削除する（`source_refs` で確認できる外部依存のみ残す・捏造しない）
- **反映は根拠のある指摘のみに行う**。fixture-architect の指摘のうち信頼度が低い / 入力不足で確認できないものは成果物へ断定反映せず、返却の所見に残す（黙殺しない・捏造しない）
- 反映後、**再度 `deep-test:fixture-architect` を単独起動して自己チェックに戻る**（再チェックループ）。重大指摘が解消するまで Phase 2 ⇄ Phase 3 を反復し、**収束（重大指摘が無くなる）してから検証チェックリスト → 確定・返却へ進む**（fixture-procedures.md 1 章フローの `L --指摘なし/軽微のみ--> N`）
- 解消できない指摘は無限ループにせず、反映しない理由を付して返却の所見に残して収束させる（agents.md 4 章）
- fixture-architect の総合所見「NEEDS REVISION 相当」は起動元の判定材料であり、**最終判定は本スキルが行う**（エージェントに総合判定・成果物修正をさせない）
- 反映しても **決定はしない**: ケースの `fixtures:` 参照・`automation: playwright-test` の選定・レベル/技法/優先度は test-design の専有（確定しない）
- **書き込み境界**を維持: SUT テストディレクトリ + `fixtures.yaml` のみを更新。`test-results.yaml` / `test-cases.yaml` / `analysis.yaml` へは書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{base}/{target-slug}/fixtures.yaml` / SUT テストコード（重大指摘を反映した**是正後**。storageState 出力先を SUT テストディレクトリへ是正・認証情報を環境変数化・auth/mock を分離・根拠なきモックを削除・`updated_at` 更新）。プロダクションコード・test-results.yaml / test-cases.yaml / analysis.yaml への変更なし。認証情報のハードコードなし |
| 標準出力（要約） | フィクスチャ構築結果サマリの「fixture-architect 自己チェック所見」に、**反映した重大指摘と再チェックで収束した旨**・反映しなかった指摘（理由付き）を明記する |
| 終了状態 | 重大指摘があるため再生成ループ（Phase 2 ⇄ Phase 3）に突入し、反映 → 再チェックを重大指摘の解消（収束）まで反復してから確定・返却。総合判定は本スキルが行う。決定は test-design へ |

## 関連ケース

- case-09: fixture-architect が軽微な指摘のみで**再生成ループに入らず返却**する分岐（本ケースの対）
- case-06: 書き込み境界・認証情報のハードコードを主軸に据えた不変条件ケース（本ケースは fixture-architect がそれらの逸脱を重大指摘として検出 → 是正する動的挙動に主眼）
- case-01: 新規生成の一連の流れで重大指摘を反映する分岐（本ケースは反映 → 再チェックの**ループ挙動そのもの**に主眼）
- case-02: 拡充時の非破壊性を fixture-architect に確認させる観点
