<!-- R13-EVAL-REPORT-09-SENTINEL-v1 -->
# case-09 自動 / 手動混在実績の報告生成（実行主体列・自動/手動内訳・免責 6 項目）

latest に自動実行（playwright-mcp / test-framework 等）と手動実施（human-assisted）の結果が混在する実績から報告書を生成した場合に、レベル別明細の「実行主体」列・サマリの「自動 / 手動」列と手動内訳注記・免責注記 6 項目（「手動」を含む）が出力されることを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動 | オーケストレータ `test` の report フェーズから委譲（対話・Excel 選択。Markdown でも同一規範） |
| 前提 | latest に `executed_by: playwright-mcp` / `test-framework` の自動結果と、`human-assisted` の手動結果（`automation: manual-assist` の pass 1 件 + `exploratory` の fail 1 件〔defect + `extras.session_findings` あり〕）が混在する。バリデーション・エビデンス監査は通過する |

## 分岐の根拠

`${CLAUDE_PLUGIN_ROOT}/references/report-format.md` 3.2（レベル別集計表の列 = 対象数 / pass / fail / blocked / skipped / na / **自動 / 手動**〔自動 = executed_by が playwright-mcp / playwright-test / test-framework / api の件数・手動 = human-assisted の件数〕と、表直下の**手動内訳注記**の定型文「手動内訳: manual-assist X 件 / exploratory Y 件。human-assisted の結果は人間の実施・申告に基づく」）・3.4（レベル別シート 14 列・9 列目「実行主体」= executed_by・14 列目「補足情報（extras）」= results[] 直下 extras の転載）・3.5（列幅: 実行主体 12）・4 章（Markdown も同一の列・集計・注記構成）・5 章（集計値は report_model.py の機械集計。LLM の手計算・手動転記禁止）・6 章（免責注記 6 項目: UAT / 性能 / セキュリティ / 再テスト / 用語 / **手動**）。

## 期待動作

- レベル別シート / セクションの明細が **14 列**で、status の直後の 9 列目に「実行主体」列（値 = `executed_by`。human-assisted / playwright-mcp / test-framework 等がそのまま出る）が出力される（14 列目は「補足情報（extras）」= results[] 直下 extras の転載・status を問わず）
- サマリのレベル別集計表に「自動」「手動」列が出力される（自動 = executed_by が playwright-mcp / playwright-test / test-framework / api の件数、手動 = human-assisted の件数。latest 採用の機械集計）
- レベル別集計表の直下に**手動内訳注記**の定型文が出力される（manual-assist X 件 / exploratory Y 件は test-cases.yaml の `automation` による機械集計値。本前提では X=1 / Y=1）
- 免責注記が **6 項目**（UAT / 性能 / セキュリティ / 再テスト / 用語 / 手動）で出力され、「手動」項目の趣旨（executed_by: human-assisted の結果は人間の実施・申告に基づく記録であり、機械検証とは実行主体が異なる）が欠落しない
- 総合判定は status 集計のみで決まる既存規則のまま（実行主体は判定に影響させない。手動 pass を格上げ・格下げしない）
- 集計値・列値は生成スクリプト（report_model.py 経由）の機械集計を用いる（LLM が executed_by を目視転記・推測補完しない）
- Excel / Markdown どちらの形式でも同一の列・内訳・免責が出力される（形式差は表現のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 報告書 1 ファイル（レベル別明細 14 列〔実行主体列・補足情報（extras）列入り〕・サマリに自動 / 手動列 + 手動内訳注記・免責 6 項目。セッション作業領域直下）。test-results.yaml は読み取りのみ |
| 標準出力（要約） | SKILL.md「引き渡し」正常フォーマット（集計はスクリプト出力の転記。自動 / 手動内訳を含む） |
| 終了状態 | 生成完了 |

## 関連ケース

- case-01: Excel 生成正常系（本ケースは自動 / 手動混在時の列・内訳・免責の観点詳細）
- case-02: Markdown 生成正常系（同一規範の別形式。6 章構成・免責は最終章）
- case-05: 複数レベル一括報告（レベル別シート構成の観点。実行主体列は全実施レベルのシートに共通）
