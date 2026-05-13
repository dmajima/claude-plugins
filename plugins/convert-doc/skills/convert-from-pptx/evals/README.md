# convert-from-pptx evals

`convert-from-pptx` スキルの動作分岐ごとの期待挙動ケース集。

## ケース一覧

| ファイル | 対象分岐 |
|---------|---------|
| [case-01_normal_with_title.md](case-01_normal_with_title.md) | 標準変換（タイトル placeholder あり、複数スライド） |
| [case-02_no_title_placeholder.md](case-02_no_title_placeholder.md) | タイトル placeholder なし → `## スライド<N>` |
| [case-03_table_conversion.md](case-03_table_conversion.md) | 表 shape → Markdown パイプ表 |
| [case-04_image_extraction.md](case-04_image_extraction.md) | 画像抽出と相対パス参照 |
| [case-05_flowchart_mermaid.md](case-05_flowchart_mermaid.md) | 図形 + コネクタ → Mermaid flowchart |
| [case-06_smartart_mermaid.md](case-06_smartart_mermaid.md) | SmartArt → Mermaid flowchart（解析可能な構造） |
| [case-07_speaker_notes.md](case-07_speaker_notes.md) | スピーカーノート（`--include-notes`） |
| [case-08_hidden_slide.md](case-08_hidden_slide.md) | 非表示スライド（`--include-hidden`） |
| [case-09_input_not_found.md](case-09_input_not_found.md) | 入力 PPTX が存在しない |
| [case-10_path_traversal_images_dir.md](case-10_path_traversal_images_dir.md) | `--images-dir` のパストラバーサル拒否 |
| [case-11_invalid_pptx_magic.md](case-11_invalid_pptx_magic.md) | ZIP マジック不一致（非 PPTX 入力） |
| [case-12_max_image_size_overflow.md](case-12_max_image_size_overflow.md) | `--max-image-size` 超過時のメタ情報フォールバック |
| [case-13_monospace_code_block.md](case-13_monospace_code_block.md) | モノスペースフォント段落 → コードブロック化 |
| [case-14_no_mermaid_flag.md](case-14_no_mermaid_flag.md) | `--no-mermaid` 指定時はフロー図変換をスキップ |
| [case-15_empty_pptx.md](case-15_empty_pptx.md) | 空 PPTX（スライド 0 枚） |
| [case-16_invalid_content_types.md](case-16_invalid_content_types.md) | Content_Types.xml が PresentationML を示さない |
| [case-17_invalid_extension.md](case-17_invalid_extension.md) | 入力拡張子が .pptx/.pptm 以外 |
| [case-18_no_first_slide_as_title.md](case-18_no_first_slide_as_title.md) | `--no-first-slide-as-title` 指定時の 1 枚目挙動 |
| [case-19_chart_shape.md](case-19_chart_shape.md) | チャート shape の要約出力 |
| [case-20_smartart_fallback.md](case-20_smartart_fallback.md) | SmartArt 解析失敗時のテキストフォールバック |
| [case-21a_zip_bomb_total_size.md](case-21a_zip_bomb_total_size.md) | ZIP bomb 防御（総展開サイズ超過） |
| [case-21b_zip_bomb_compression_ratio.md](case-21b_zip_bomb_compression_ratio.md) | ZIP bomb 防御（圧縮率異常） |
| [case-22_image_extension_allowlist.md](case-22_image_extension_allowlist.md) | 画像拡張子 allowlist による正規化 |

## 実行確認方法

```bash
python "${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-from-pptx/convert_from_pptx.py" <入力PPTX> <出力MD> [オプション]
```
