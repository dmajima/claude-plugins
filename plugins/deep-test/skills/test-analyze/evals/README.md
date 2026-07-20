# test-analyze evals

本ディレクトリは `test-analyze` フェーズスキル（Phase 1.5）の **AI の動作分岐検証ケース集**。
1 ケース 1 ファイルで、スキルの規範（SKILL.md / references/ / プラグイン共通 references）に基づく分岐ごとに期待動作を定義する。

## ケース一覧

| case | ファイル名 | 検証する分岐 | 起動形態 |
|------|-----------|------------|---------|
| 01 | case-01_full_source_analysis.md | source_availability=full の全材料生成（アーキ / 依存 / EP / 複雑度 × churn / テスタビリティ / リスク / 攻撃面 / 品質特性 → analysis.yaml + target-analysis.md → source-analyst 自己チェック） | 単独・対話 |
| 02 | case-02_spec_provided.md | `spec=` 指定あり（仕様書突合で spec_divergence を材料化。未指定時は非出力） | 委譲 |
| 03 | case-03_change_impact_diff.md | `diff=` 指定あり（変更ファイル → 依存逆引きで change_impact・回帰スコープ提案。未指定時は非出力） | 委譲 |
| 04 | case-04_source_none_degraded.md | source_availability=none の縮退（コード解析スキップ・confidence: low・捏造禁止・open_questions 記録） | 委譲 |
| 05 | case-05_non_interactive.md | 非対話モード（委譲・target-slug / base 付与で自動進行・AskUserQuestion 不使用） | 委譲・非対話 |
| 06 | case-06_source_partial_degraded.md | source_availability=partial の縮退（取得可能範囲のみ解析・欠落を open_questions・セクション別 confidence / 充足度・full とも none とも異なる独立経路） | 委譲 |
| 07 | case-07_target_slug_multiple_non_interactive.md | 非対話 × 既存 target-slug 複数（自動選択せずエラー中断・材料生成前に停止。target-slug 解決軸） | 委譲・非対話 |
| 08 | case-08_target_slug_single_non_interactive_auto.md | 非対話 × 既存 target-slug 単一（唯一の既存 slug を自動採用し解析続行・採用根拠を明記。target-slug 解決軸） | 委譲・非対話 |
| 09 | case-09_target_unspecified_interactive.md | 解析対象（対象説明= / 位置引数 / spec）が完全未指定 × 対話（AskUserQuestion で確認。対象未指定軸・target-slug 解決とは別） | 委譲・単独 |
| 10 | case-10_target_unspecified_non_interactive_error.md | 解析対象が完全未指定 × 非対話（AskUserQuestion 不可でエラー中断。case-09 の対） | 委譲・単独 |
| 11 | case-11_complexity_tool_available.md | 複雑度計測ツール（radon / lizard 等）利用可（hotspots を measured: true + 実数値化。既存は measured: false 側のみ） | 委譲 |
| 12 | case-12_source_analyst_minor_findings.md | source-analyst 自己チェックが軽微な指摘のみ（重大指摘なし・反映 or 理由付き返却・再生成ループに入らない） | 委譲 |
| 13 | case-13_target_slug_zero_non_interactive.md | 非対話 × 既存 target-slug 0 件（対象名から kebab-case で slug を自動生成して新規採用・対象名を特定できない場合は捏造せずエラー中断。target-slug 解決軸） | 委譲・非対話 |
| 14 | case-14_target_slug_existing_interactive.md | 対話 × 既存 target-slug 1 件以上（AskUserQuestion で既存一覧＋「新規作成」を提示し、既存再利用 or 新規作成でユーザー選択分岐。target-slug 解決軸） | 単独・対話 |
| 15 | case-15_source_analyst_major_findings.md | source-analyst 自己チェックが重大指摘あり（材料へ反映してから再度自己チェックへ戻り、収束まで Phase 2 ⇄ Phase 3 を反復・case-12 の対） | 委譲 |

## ケースファイルの構成

各ケースファイルは以下のセクションで構成する。

| セクション | 内容 |
|-----------|------|
| 入力 | 委譲 args または起動フレーズ / 起動形態（委譲・単独）・前提状態 |
| 分岐の根拠 | SKILL.md / references のどの規範に基づく分岐か（ファイル名・章を明記） |
| 期待動作 | 検証可能な期待動作の箇条書き（解析内容・生成物・起動するエージェント・返却内容） |
| 期待出力 | 生成ファイル / 標準出力（要約）/ 終了状態の表（生成物と返却内容への参照でよい） |
| 関連ケース | 対になる分岐・前提となるケースへの参照 |

## 軸と不変条件について

本スキルの evals は「委譲（オーケストレータ `test` 経由）/ 単独」と「対話 / 非対話」、および入力オプション（`spec=` / `diff=` の有無）と `source_availability`（full / partial / none）の縮退軸で分岐を検証する。
縮退軸は両端点（full = case-01 / none = case-04）と中間（partial = case-06。取得可能範囲のみ解析し欠落を `open_questions` へ）をケース化し、同じ不変条件で扱う。partial はコード解析を全スキップせず、取得済み EP・hotspots と欠落 open_questions が 1 材料内に併存してセクションごとに `confidence` / 充足度が分かれる（full 一律 / none 一律のいずれとも異なる独立経路）。

さらに、入力欠落に関わる 2 軸を独立して検証する。

- **target-slug 解決軸**（どのデータ配置領域を使うか。`data-locations.md` 4.2 章の解決フロー図が SSOT）: まず委譲で target-slug 付与済みなら解決フローに入らず受領値を使う = case-05。解決フローに入る場合は「既存 slug 件数（0 / 1 / 複数）× 対話 / 非対話」の 6 分岐をすべてケース化する。非対話側は、既存 0 件 = 対象名から kebab-case で自動生成・特定不可はエラー中断 = case-13 / 既存 1 件 = 唯一の既存を自動採用 = case-08 / 既存複数 = 自動選択せずエラー中断 = case-07。対話側は、既存 0 件 = 新規 slug 名を確認して作成（case-01 のフル解析内で実施）/ 既存 1 件以上（1 件・複数とも同一） = AskUserQuestion で既存一覧＋「新規作成」を提示し既存再利用 or 新規作成で分岐 = case-14。これにより 6 分岐（0 件 / 1 件 / 複数 × 対話 / 非対話）が case で埋まる。
- **対象未指定（入力不足）軸**（何を解析対象とするか。`対象説明=` / 位置引数 / `spec=` のいずれも無い）: 対話は AskUserQuestion で確認 = case-09 / 非対話はエラー中断 = case-10。これは target-slug 解決軸とは別物であり（「どのデータ領域か」ではなく「何を解析するか」の欠落）、slug が確定していても対象説明が無ければこの軸に入る。

加えて、複雑度計測ツールの有無は hotspots の `measured` を分ける（ツール無し = `false`〔case-01 等〕/ ツール有り = `true` + 実数値〔case-11〕）。source-analyst 自己チェックの結果取り扱いは、**軽微指摘のみ（case-12。反映 or 理由付き返却・再生成ループに入らない）と重大指摘あり（case-15。材料へ反映してから再度自己チェックへ戻り、収束まで Phase 2 ⇄ Phase 3 を反復）の 2 分岐**で検証する（case-01 等の full 正常系も重大指摘を 1 度反映するが、反映 → 再チェックの反復挙動そのものの検証は case-15 が担う）。

どの分岐でも共通する不変条件:

- 材料生成に徹し **決定をしない**（レベル / 技法 / 優先度 / ケースを確定せず、`suggested_focus` 等は hint に留める。決定は test-design）
- read-only の静的理解に徹し、SUT のプロダクションコード・test-results.yaml / test-cases.yaml / test-plan.md へ書き込まない（材料 analysis.yaml / target-analysis.md のみ生成）
- 数値は計測ツールが無ければ `measured: false` + `null`（捏造禁止）、取得できなかった事項は `open_questions` に必ず記録する
- 生成後に `source-analyst` を **単独起動** して自己チェックし、重大指摘を反映してから返却する（並列起動しない・エージェントに材料を修正させない）
