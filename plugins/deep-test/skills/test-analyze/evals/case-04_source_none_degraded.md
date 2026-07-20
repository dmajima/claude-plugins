# case-04 ソース不在の縮退（source_availability none・コード解析スキップ・捏造禁止）

ソースが取得できない（仕様書のみ / デプロイ済み外部システム）ケース。コードベース解析をスキップし spec / 公開仕様から静的導出する縮退動作を検証する。`confidence: low`・推定値の捏造禁止・`open_questions` 記録を厳守する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `対象説明=https://example.test の受注管理 Web spec=docs/spec.md target-slug=orderapp-web base=<base>` |
| 起動形態 | 委譲（オーケストレータ `test` から Skill ツール経由） |
| 前提 | 対象はデプロイ済み外部システムでソースツリー非提供（Glob / Read で取得不能）/ 仕様書 `docs/spec.md` と公開 API ドキュメントのみ取得可 / 複雑度計測・git churn の対象リポジトリなし |

## 分岐の根拠

SKILL.md「実行フロー」2〜3（source_availability 判定）・「重要な制約」（捏造禁止・縮退時 `confidence: low`・縮退セクションの明示）、references/procedures.md 3 章（`none` の判定例）・5 章（縮退動作表: `none` はコード解析スキップ・spec / 公開仕様から導出・推定値の捏造禁止・確認できない事項は `open_questions`）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-analysis.md` 16 章（`none` の縮退動作）・7 章（`measured: false` + `null`）・15 章（open_questions は必ず記録）、同 `execution-policy.md` 2 章 / 9 章（SKIPPED 原則・実行を偽装しない）。

## 期待動作

- `source_availability` を `none` と判定し、判定根拠（ソースツリー非提供・仕様書と公開仕様のみ）を target-analysis.md 冒頭に明記する
- コードベース解析（複雑度・churn・依存グラフ・seam 検出）を **スキップ** する（稼働アプリへの能動プローブもしない = 動的探索は test-run-* / test-setup の責務）
- entry_points は `spec=` / API ドキュメント / 公開仕様から静的に導出する（確認できた範囲のみ。`source_ref` は捏造しない）
- hotspots の複雑度・churn は計測対象が無いため `cyclomatic_complexity: null` / `churn: null` + `measured: false` とする（実測のように書かない）
- risk_register の likelihood は仕様 complexity・外部 IF 数から弱く推定し、所見に `confidence: low` を付与する
- attack_surface は文書化された公開 EP から STRIDE 所見を作成する
- 縮退でスキップ・推定に留めた事項を `open_questions` に必ず記録する（捏造禁止）。target-analysis.md の該当章は「縮退（ソース不在）」と明示する
- risk_register の `suggested_focus` 等は hint に留める（縮退下でも決定はしない = 決定は test-design）
- source-analyst 自己チェックで縮退整合（confidence / measured / open_questions の誠実な併用）を確認させ、重大指摘を反映する
- read-only に徹し、SUT / 稼働アプリへ書き込まない。test-results.yaml / test-cases.yaml / test-plan.md へも書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{target-slug}/analysis.yaml`（`meta.source_availability: none`・EP は仕様由来・hotspots は `measured: false` + `null`・risk_register は `confidence: low`・`open_questions` に縮退事項）・`{target-slug}/target-analysis.md`（縮退章に「縮退（ソース不在）」明示）。test-results.yaml / test-cases.yaml / test-plan.md へは書き込まない |
| 標準出力（要約） | 解析結果サマリ（source_availability: none・縮退したセクションの明示・confidence: low）と、open_questions の列挙（推定に留まる項目・確認不能事項） |
| 終了状態 | コード解析をスキップした縮退材料を返却。数値は捏造せず `measured: false`、未確認は open_questions に記録。決定は test-design へ |

## 関連ケース

- case-01: source_availability=full（全解析する側の正常系）
- case-05: 非対話モードの分岐（縮退判定ロジック自体は同じ）
