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

## 実行確認方法

```bash
python "${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-pptx/convert_pptx.py" <ケースの入力> <出力> [オプション]
```
