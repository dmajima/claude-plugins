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
| [case-23a_structured_json_normal.md](case-23a_structured_json_normal.md) | Phase 1 JSON モード（`--structured-json` + `--json-only`）正常系 |
| [case-23b_json_only_alone.md](case-23b_json_only_alone.md) | `--json-only` 単独指定（無効組み合わせ） |
| [case-24a_per_slide_json.md](case-24a_per_slide_json.md) | `--per-slide-json` スライド単位 JSON 出力 |
| [case-24b_compact_view.md](case-24b_compact_view.md) | `--compact-view` 簡潔ビュー出力 |
| [case-25a_verify_pass.md](case-25a_verify_pass.md) | Phase 3 `verify_md.py` カバレッジ PASS |
| [case-25b_verify_fail.md](case-25b_verify_fail.md) | Phase 3 カバレッジ閾値未達 FAIL |
| [case-25c_verify_suspicious.md](case-25c_verify_suspicious.md) | Phase 3 誤転記候補 `suspicious_md_phrases` 検出 |
| [case-26_interactive_mode.md](case-26_interactive_mode.md) | 対話モード（AskUserQuestion フロー） |
| [case-27_fallback_mode.md](case-27_fallback_mode.md) | フォールバックモード（Python 単独 Markdown 直接生成） |
| [case-28_lr_flowchart.md](case-28_lr_flowchart.md) | フロー図 `LR`（横方向）Mermaid 出力 |
| [case-29_content_types_missing.md](case-29_content_types_missing.md) | `[Content_Types].xml` 欠落（KeyError パス） |
| [case-30_title_estimation_fallback.md](case-30_title_estimation_fallback.md) | タイトル代替推定（`_guess_title_shape` の優先順位 A/B 経路） |
| [case-31_workspace_root_traversal.md](case-31_workspace_root_traversal.md) | `--workspace-root` 経由のパストラバーサル拒否（CWE-22） |
| [case-32_json_and_md_dual_output.md](case-32_json_and_md_dual_output.md) | `--json-only` なし + `--structured-json` で JSON + MD 同時出力 |
| [case-33_decoration_reasons_boundary.md](case-33_decoration_reasons_boundary.md) | 装飾判定 `decoration_reasons >= 2` の境界値 |
| [case-34_verify_image_50pct_boundary.md](case-34_verify_image_50pct_boundary.md) | `verify_md.py` 画像カバレッジ 50% 境界値 |
| [case-35_verify_connector_threshold_5.md](case-35_verify_connector_threshold_5.md) | `verify_md.py` コネクタ閾値 5 件境界値 |
| [case-36_default_md_output_path.md](case-36_default_md_output_path.md) | 出力 MD パス省略時のデフォルト解決（`<入力>.md`） |
| [case-37_title_estimation_boundary.md](case-37_title_estimation_boundary.md) | `_guess_title_shape` 優先順位 A/B の EMU 境界値 |
| [case-38_merged_cell_table.md](case-38_merged_cell_table.md) | マージセル（colspan / rowspan）を含むテーブル |
| [case-39_empty_table_skip.md](case-39_empty_table_skip.md) | 全セル空テーブルの除外 |
| [case-40_horizontal_text_merge.md](case-40_horizontal_text_merge.md) | 水平方向の連続テキスト行結合（`_merge_horizontal_text_rows`） |
| [case-41a_force_overwrite.md](case-41a_force_overwrite.md) | `--force` フラグによる既存ファイル上書き許可 |
| [case-41b_symlink_output_rejected.md](case-41b_symlink_output_rejected.md) | 出力先が symlink なら `--force` 有無を問わず拒否（CWE-59） |
| [case-42a_max_slides_exceeded.md](case-42a_max_slides_exceeded.md) | `MAX_SLIDES` 上限超過時の拒否（DoS 防御） |
| [case-42b_max_shapes_exceeded.md](case-42b_max_shapes_exceeded.md) | `MAX_SHAPES_PER_SLIDE` 上限超過時の拒否（DoS 防御） |
| [case-42c_max_group_depth_exceeded.md](case-42c_max_group_depth_exceeded.md) | `MAX_GROUP_DEPTH` 上限超過時の拒否（CWE-674） |
| [case-42d_max_image_count_exceeded.md](case-42d_max_image_count_exceeded.md) | 画像総量・枚数の上限超過時の拒否（DoS 防御） |
| [case-43_large_pptx_subagent_flow.md](case-43_large_pptx_subagent_flow.md) | 大規模 PPTX（100 スライド超）でのサブエージェント並列分担フロー |
| [case-44_xml_hardening_without_defusedxml.md](case-44_xml_hardening_without_defusedxml.md) | `defusedxml` 非依存での XML 攻撃保護（ZIP bomb 検査 + 上限定数）と起動成功 |
| [case-47_fail_close_stderr_flush.md](case-47_fail_close_stderr_flush.md) | fail-close 経路の stderr が `Start-Process` リダイレクトでも欠落しない（flush 強制） |
| [case-48_wrapper_timeout_exit124.md](case-48_wrapper_timeout_exit124.md) | `run_via_job.sh` のタイムアウト発火と exit 124 返却 |
| [case-49_wrapper_no_python_exe_exit2.md](case-49_wrapper_no_python_exe_exit2.md) | `run_via_job.sh` の PythonExe 引数エラー（未指定 / 不在 / .exe 拒否） |
| [case-50_wrapper_extra_args_passthrough.md](case-50_wrapper_extra_args_passthrough.md) | `run_via_job.sh` の ExtraArgs (`--no-mermaid` 等) 転送確認 |
| [case-45_medium_pptx_flow.md](case-45_medium_pptx_flow.md) | 中規模 PPTX（30〜100 スライド）でのメイン逐次 Read フロー |
| [case-46_section_cover_number_excluded.md](case-46_section_cover_number_excluded.md) | 章扉スライドでの装飾的章番号除外（`_is_decoration_number`） |

## 実行確認方法

```bash
& "$SESSION_DIR/workspace/.venv/Scripts/python.exe" \
  "$CLAUDE_PLUGIN_ROOT/references/scripts/convert-from-pptx/convert_from_pptx.py" \
  "<入力PPTX>" "<出力MD>" [オプション]
```

<details><summary>PowerShell フォールバック</summary>

```powershell
& "$SESSION_DIR/workspace/.venv/Scripts/python.exe" `
  "${env:CLAUDE_PLUGIN_ROOT}/references/scripts/convert-from-pptx/convert_from_pptx.py" `
  "<入力PPTX>" "<出力MD>" [オプション]
```

</details>
