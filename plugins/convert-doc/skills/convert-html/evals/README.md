# convert-html evals

`convert-html` スキルの動作分岐ごとの期待挙動ケース集。

## ケース一覧

| ファイル | 対象分岐 | モード |
|---------|---------|-------|
| [case-01_css_single_no_prompt.md](case-01_css_single_no_prompt.md) | CSS 合算 1 ファイル → 選択プロンプトなし | 対話/非対話 共通 |
| [case-02_css_multi_interactive.md](case-02_css_multi_interactive.md) | CSS 合算 2-3 ファイル → AskUserQuestion で選択 | 対話 |
| [case-03_css_over4_text_select.md](case-03_css_over4_text_select.md) | CSS 合算 4 ファイル以上 → テキストベース選択 | 対話 |
| [case-04_js_exclude_interactive.md](case-04_js_exclude_interactive.md) | features.json に機能あり、除外選択 | 対話 |
| [case-05_js_all_disabled.md](case-05_js_all_disabled.md) | 「全て不要」選択 → JS なし出力 | 対話 |
| [case-06_js_features_over3_text_select.md](case-06_js_features_over3_text_select.md) | features.json 3 機能以上 → テキスト選択 | 対話 |
| [case-07_non_interactive_full_features.md](case-07_non_interactive_full_features.md) | `/convert-html-full` または別スキルからの呼び出し → 全機能デフォルト | 非対話 |
| [case-08_input_file_not_found.md](case-08_input_file_not_found.md) | 入力 MD ファイルが存在しない → エラー | エラー系 |
| [case-09_mermaid_ink_unavailable.md](case-09_mermaid_ink_unavailable.md) | mermaid.ink 不通 → エラーブロック出力 | エラー系 |
| [case-10_no_h2_no_toc.md](case-10_no_h2_no_toc.md) | H2 がない MD → 目次サイドバーが空 | 境界 |
| [case-11_path_traversal_image.md](case-11_path_traversal_image.md) | 画像 src が `../` を含む → 元 src を維持（埋め込まない） | セキュリティ |
| [case-12_trigger_md_to_html.md](case-12_trigger_md_to_html.md) | トリガー: Markdown→HTML 変換の基本依頼 | 対話 |
| [case-13_trigger_design_doc_html.md](case-13_trigger_design_doc_html.md) | トリガー: 設計書 HTML 出力の自然言語依頼 | 対話 |
| [case-14_trigger_report_html.md](case-14_trigger_report_html.md) | トリガー: 資料 HTML 化の自然言語依頼 | 対話 |
| [case-15_noninteractive_full.md](case-15_noninteractive_full.md) | `/convert-html-full` による非対話モード（全機能有効） | 非対話 |

## 実行確認方法

各ケースは Claude Code 上で当該スキルを起動し、ケースに記載された期待動作と一致するかを目視確認する。
スクリプト直接実行で検証する場合は以下:

```bash
python "${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-html/convert.py" <ケースの入力> <出力> [オプション]
```

期待出力の差分を `diff` で確認することも可能。
