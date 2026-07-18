# case-05 複数レベル一括報告（1 ファイル・実施レベルのみシート分け）

複数テストレベル（例: unit / functional / system / performance）を実施した実績から、
1 ファイル内でレベル別にシート / セクション分けした一括報告が生成されることを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動 | オーケストレータ `test` の report フェーズから委譲（対話・Excel 選択） |
| 前提 | latest に 3 レベル以上の結果が存在する（例: unit / functional / integration-external / system / performance）。uat / security 等の未実施レベルもケース定義上は存在しうる |

## 分岐の根拠

`${CLAUDE_PLUGIN_ROOT}/references/report-format.md` 1 章（複数レベルの一括報告は 1 ファイル内。Excel = シート分け / Markdown = セクション分け）・
3.1（レベル別シートは**実施レベルのみ**作成。level 値 → シート表示名の対応）・6 章（免責注記は実施していないレベルの項目も削除しない）、
`${CLAUDE_PLUGIN_ROOT}/references/retest-policy.md` 5 章（latest 採用の集計）。

## 期待動作

- 報告書は **1 ファイルのみ**生成される（レベルごとにファイルを分割しない）
- Excel: シート構成は「サマリ」「推移」+ 実施レベルのシートのみ（例: ユニット / 単体 / 外部結合 / システム / 性能）。未実施レベル（受入(UAT) / セキュリティ等）のシートは作られない（スクリプトが保証）
- シート表示名は report-format.md 3.1 の対応表どおり（unit=ユニット、functional=単体、integration-external=外部結合 等）
- サマリのレベル別集計表は実施レベルの行 + 合計行で構成され、値は latest 採用の機械集計（対象数 / pass / fail / blocked / skipped / na）
- Markdown 選択時も同様に、3 章「レベル別結果」内のセクション分けで 1 ファイルに収まる
- 免責注記 5 項目（UAT / 性能 / セキュリティ / 再テスト / 用語）は、未実施レベルに関する項目も削除されない
- 返却サマリのシート / 章構成はスクリプト標準出力の転記（LLM が構成を推測で記述しない）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 報告書 1 ファイル `test-report_{target-slug}_{yyyyMMdd}.xlsx`（1 ファイル内で実施レベルのみシート分け・セッション作業領域直下）。test-results.yaml は読み取りのみ |
| 標準出力（要約） | SKILL.md「引き渡し」正常フォーマット（集計は latest 採用の機械集計、シート / 章構成はスクリプト出力の転記） |
| 終了状態 | 生成完了 |

## 関連ケース

- case-01: Excel 生成正常系（本ケースはそのシート分け観点の詳細）
- case-02: Markdown のセクション分け（同一規範の別形式）
