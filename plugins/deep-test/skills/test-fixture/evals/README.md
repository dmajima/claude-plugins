<!-- TEST-FIXTURE-EVALS-README-SENTINEL-v1 -->
# test-fixture evals

本ディレクトリは `test-fixture` フェーズスキル（Phase 1.6）の **AI の動作分岐検証ケース集**。
1 ケース 1 ファイルで、スキルの規範（SKILL.md / references/ / プラグイン共通 references）に基づく分岐ごとに期待動作を定義する。

## ケース一覧

| case | ファイル名 | 検証する分岐 | 起動形態 |
|------|-----------|------------|---------|
| 01 | case-01_web_app_new_fixtures.md | web-app・既存基盤なしでの新規生成（analysis.yaml 消費 → 認証/モック/シード/base を生成 → playwright.config.ts + fixtures.yaml → fixture-architect 自己チェック） | 単独・対話 |
| 02 | case-02_existing_extend_nondestructive.md | 既存 Playwright 基盤ありでの拡充（不足分のみ非破壊マージ・既存の書式/命名を尊重・status=extended/existing） | 委譲 |
| 03 | case-03_noop_unit_only_non_web.md | no-op（unit のみ / 非 web / 材料なし）で SUT へ書き込まず空 fixtures.yaml + 理由を返す非破壊分岐 | 委譲 |
| 04 | case-04_non_interactive.md | 非対話モード（委譲・target-slug / base / project 付与で自動進行・確認をせず `.gitignore` 追記は提案に留める） | 委譲・非対話 |
| 05 | case-05_analysis_missing_light_supplement.md | analysis.yaml 欠落時の軽量補完（Read/Glob/Grep で補完・analysis_consumed: false・confidence を下げる・能動プローブしない） | 単独 |
| 06 | case-06_write_boundary_no_hardcode.md | 書き込み境界の遵守（SUT テストディレクトリのみ・プロダクションコード不変・認証情報のハードコード回避・.gitignore 追記提案・test-results/cases/analysis 不可） | 委譲 |
| 07 | case-07_target_unspecified_non_interactive_error.md | 対象説明も analysis.yaml 材料も皆無 × 非対話（AskUserQuestion を出せずエラー中断・対象を推定せず捏造生成しない・空 fixtures.yaml も書かない） | 委譲・非対話 |
| 08 | case-08_target_unspecified_interactive.md | 対象説明も analysis.yaml 材料も皆無 × 対話（AskUserQuestion で対象 or 先行 test-analyze を確認・提示まで生成しない） | 単独・対話 |
| 09 | case-09_fixture_architect_minor_findings.md | fixture-architect 自己チェックが軽微指摘のみ（重大指摘なし → 再生成ループ非突入・反映 or 理由付き所見・最終判定は本スキル） | 委譲 |
| 10 | case-10_fixture_architect_major_findings.md | fixture-architect 自己チェックが重大指摘（書込境界逸脱/認証ハードコード等 → 設計へ反映 → 再チェックループで収束） | 委譲 |
| 11 | case-11_target_slug_multiple_non_interactive.md | 非対話 × 既存 target-slug 複数 → エラー中断（slug 自動選択せず・生成前に停止。対象不在 case-07 とは別軸。test-analyze case-07 の様式） | 委譲・非対話 |
| 12 | case-12_target_slug_existing_interactive.md | 対話 × 既存 target-slug 1 件以上 → AskUserQuestion で既存一覧+新規作成を提示し選択で分岐（test-analyze case-14 の様式） | 単独・対話 |
| 13 | case-13_target_slug_single_non_interactive_auto.md | 非対話 × 既存 target-slug 単一 → 自動採用（唯一の既存 slug を採用して構築続行。case-11 の対。test-analyze case-08 の様式） | 委譲・非対話 |
| 14 | case-14_target_slug_zero_non_interactive.md | 非対話 × 既存 target-slug 0 件 → 対象名から kebab-case 自動生成〔特定不可はエラー中断〕。新規 slug 配下は analysis 欠落で case-05 の軽量補完（test-analyze case-13 の様式） | 委譲・非対話 |

## ケースファイルの構成

各ケースファイルは以下のセクションで構成する。

| セクション | 内容 |
|-----------|------|
| 入力 | 委譲 args または起動フレーズ / 起動形態（委譲・単独）・前提状態 |
| 分岐の根拠 | SKILL.md / references のどの規範に基づく分岐か（ファイル名・章を明記） |
| 期待動作 | 検証可能な期待動作の箇条書き（消費内容・生成物・起動するエージェント・返却内容） |
| 期待出力 | 生成ファイル / 標準出力（要約）/ 終了状態の表（生成物と返却内容への参照でよい） |
| 関連ケース | 対になる分岐・前提となるケースへの参照 |

## 軸と不変条件について

本スキルの evals は「委譲（オーケストレータ `test` 経由）/ 単独」と「対話 / 非対話」、および「既存基盤の有無（新規生成 = case-01 / 拡充 = case-02）」「fixture 要否（有効 = case-01 / no-op = case-03）」「材料の有無（analysis.yaml 消費 = case-01 / 軽量補完 = case-05）」「target-slug 解決（非対話の既存複数 = case-11 はエラー中断 / 非対話の既存単一 = case-13 は自動採用 / 非対話の既存 0 件 = case-14 は対象名から自動生成〔特定不可はエラー中断〕 / 対話の既存選択 = case-12、data-locations.md 4.2 章。対象説明の不在〔case-07 / 08〕とは別軸）」の分岐を検証する。
これに加えて「**入力不足軸**（対象説明も analysis.yaml 材料も皆無で軽量補完もできない場合の挙動: 非対話 = case-07 はエラー中断・対話 = case-08 は AskUserQuestion で確認。いずれも対象を推定せず捏造生成しない）」と「**自己チェック重大度軸**（fixture-architect 自己チェックの結果分岐: 軽微指摘のみ = case-09 は再生成ループに入らず反映 or 理由付き所見・重大指摘 = case-10 は成果物へ反映してから再チェックループで収束）」を検証する。入力不足軸は「材料の有無」軸の延長（軽量補完 = case-05 のさらに手前＝対象自体が特定できない縁）であり、対象・材料が皆無なら生成に進まず中断/確認する点で case-05 と分かれる。自己チェック重大度軸は case-01〜06 が「重大指摘を反映して返却」までを前提に置くのに対し、重大度ごとの取り扱い（軽微のみは非ループ / 重大は反映 → 再チェックループ）を独立に固定する。
書き込み境界と認証情報の安全性は全ケース共通の不変条件だが、その遵守そのものを主軸に据えたケースを case-06 として独立に置く。case-10 は fixture-architect がその書き込み境界逸脱・認証情報ハードコードを**重大指摘として検出し是正する動的挙動**を扱い、case-06（不変条件そのものの固定）と補完関係にある。

どの分岐でも共通する不変条件:

- **書き込み境界**: 生成 / 拡充は **SUT のテストディレクトリ**（`{project}/{test_root}/` ・`playwright.config.ts`）に限定し、SUT のプロダクションコード・`test-results.yaml` / `test-cases.yaml` / `analysis.yaml` へは書き込まない（`playwright-test.md` 4 章が SSOT）
- **認証情報のハードコード禁止**: 実値を config / fixture / setup に書かず、環境変数・credentials-manager 経由の取得コードにする。storageState 出力先は `.gitignore` 追記を提案する（実トークンをコミットしない）
- **決定をしない**: ケースの `fixtures:` 参照・`automation: playwright-test` の選定・レベル/技法/優先度は test-design の専有。本スキルは下地（fixture コード + マニフェスト）を作るに徹する
- **no-op 分岐**: 非 web / unit のみ / 材料なしなら SUT に何も書かず空 fixtures.yaml + 理由で正常終了する（既存 MCP フローを壊さない）
- **捏造禁止**: analysis.yaml 未消費時は `analysis_consumed: false` と `confidence` を下げ、推定を確定情報として書かない。稼働アプリへの能動プローブ（実ログイン試行等）はしない
- 生成後に `fixture-architect` を **単独起動** して自己チェックし、重大指摘を反映してから返却する（並列起動しない・エージェントに成果物を修正させない）
