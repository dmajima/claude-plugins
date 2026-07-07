# convert-pptx evals

`convert-pptx` スキルの動作分岐ごとの期待挙動ケース集。

## ケース一覧

| ファイル | 対象分岐 |
|---------|---------|
| [case-01_normal_with_h2.md](case-01_normal_with_h2.md) | 標準変換（H2 複数） |
| [case-02_no_h2_single_slide.md](case-02_no_h2_single_slide.md) | H2 が 1 つもない |
| [case-03_mermaid_ink_unavailable.md](case-03_mermaid_ink_unavailable.md) | mermaid.ink 不通 → テキストフォールバック |
| [case-04_body_chars_overflow.md](case-04_body_chars_overflow.md) | --max-body-chars 超過 |
| [case-05_aspect_4_3.md](case-05_aspect_4_3.md) | --aspect 4:3 |
| [case-06_input_not_found.md](case-06_input_not_found.md) | 入力 MD が存在しない |
| [case-07_invalid_primary_color.md](case-07_invalid_primary_color.md) | 不正な --primary-color |
| [case-08_ssrf_image_url.md](case-08_ssrf_image_url.md) | プライベート IP の画像 URL（SSRF 対策） |
| [case-09_trigger_md_to_pptx.md](case-09_trigger_md_to_pptx.md) | トリガー: Markdown→PPTX 変換の基本依頼（対話モード） |
| [case-10_trigger_slide_creation.md](case-10_trigger_slide_creation.md) | トリガー: スライド作成の自然言語依頼（対話モード） |
| [case-11_trigger_design_doc_pptx.md](case-11_trigger_design_doc_pptx.md) | トリガー: 設計書 PPTX 出力の自然言語依頼（対話モード） |
| [case-12_noninteractive_aspect.md](case-12_noninteractive_aspect.md) | 4:3 アスペクト比指定による非対話モード（`--aspect 4:3` 適用） |
| [case-13_theme_selection.md](case-13_theme_selection.md) | テーマ選択 UI（対話・テーマ 1〜2 個） |
| [case-14_local_image_traversal.md](case-14_local_image_traversal.md) | ローカル画像のパストラバーサル拒否 |
| [case-15_theme_zero_default.md](case-15_theme_zero_default.md) | テーマ 0 個 → 選択 UI なしでデフォルト |
| [case-16_theme_text_selection_over3.md](case-16_theme_text_selection_over3.md) | テーマ 3 個以上 → テキスト選択に切替 |
| [case-17_theme_noninteractive.md](case-17_theme_noninteractive.md) | 非対話呼び出し時のテーマ扱い |
| [case-18_theme_named_resolution.md](case-18_theme_named_resolution.md) | テーマ名の明示指定（一致 / 不一致） |
| [case-19_theme_with_primary_override.md](case-19_theme_with_primary_override.md) | テーマと `--primary-color` の併用（優先順位） |
| [case-20_mermaid_bad_response.md](case-20_mermaid_bad_response.md) | mermaid.ink の不正レスポンス（200 だが PNG でない） |
| [case-21_invalid_theme_json.md](case-21_invalid_theme_json.md) | 変換時の不正テーマ JSON → exit 1 |
| [case-22_trigger_negative.md](case-22_trigger_negative.md) | トリガー判定: 起動しないべき入力（負例） |
| [case-23_theme_name_precedence.md](case-23_theme_name_precedence.md) | 同名テーマの優先解決（skill > plugin > local） |
| [case-24_local_image_success.md](case-24_local_image_success.md) | ローカル画像の正常埋め込み（受理側） |
| [case-25_mermaid_success.md](case-25_mermaid_success.md) | mermaid 図の正常埋め込み（受理側） |
| [case-26_no_h1_no_title_slide.md](case-26_no_h1_no_title_slide.md) | H1 なし → タイトルスライドを生成しない |
| [case-27_missing_input_arg.md](case-27_missing_input_arg.md) | input 引数省略 → exit 2（argparse 経路） |
| [case-28_default_output_path.md](case-28_default_output_path.md) | output 省略時のデフォルト出力パス |

## デモ実行スクリプト

[`demo.sh`](demo.sh) は主要経路（デフォルト変換 / テーマ適用 / dump-default-theme / エラー系）を
実 venv で通しで確認する再現スクリプト。実行方法はスクリプト冒頭のコメントを参照。

## 実行確認方法

```bash
python "${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-pptx/convert_pptx.py" <ケースの入力> <出力> [オプション]
```
