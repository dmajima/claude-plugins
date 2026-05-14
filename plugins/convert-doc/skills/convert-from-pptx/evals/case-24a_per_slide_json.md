# Case 24a: `--per-slide-json` でスライド単位 JSON + メタデータ出力

## 入力

- 入力 PPTX: 5 スライド構成の有効な PPTX
- 出力 MD: 未指定（`--json-only` 併用）
- オプション: `--per-slide-json <セッション>/json/ --json-only`

## 期待動作

1. `_validate_pptx()` で入力 PPTX を検証
2. `export_per_slide_json()` がスライドごとに `slide-NN.json` を分割出力
3. 同時に `metadata.json` を出力し、`slides_index[]` に各スライドのサマリ（layout_name / shape_count / connector_count / has_notes）を含める
4. 画像は単一の `<basename>_images/` に共通抽出される
5. 終了コード: 0

## 期待出力

```
<セッション>/json/
├── metadata.json
├── slide-01.json
├── slide-02.json
├── slide-03.json
├── slide-04.json
└── slide-05.json
```

`metadata.json` の内容:
```jsonc
{
  "input_path": "...",
  "slide_count": 5,
  "slide_width_emu": 12192000,
  "slide_height_emu": 6858000,
  "images_dir": "...",
  "template_decoration_texts": [...],
  "schema_version": "1.0",
  "slides_index": [
    {"slide_no": 1, "layout_name": "Title Slide", "is_section_cover_layout": false, "shape_count": 3, "connector_count": 0, "has_notes": false, "file": "slide-01.json"},
    ...
  ]
}
```

## 分岐の根拠

`convert_from_pptx.py:export_per_slide_json()`:
```python
slide_path = self.per_slide_json_dir / f"slide-{emitted:02d}.json"
with open(slide_path, "w", encoding="utf-8", newline="\n") as fh:
    json.dump(slide_data, fh, ensure_ascii=False, indent=2)
slide_summaries.append({...})
```

中〜大規模 PPTX 向けのコンテキストウィンドウ負荷分散フロー（`large-pptx-workflow.md` 節 2）の中核。

## 関連ケース

- [case-24b_compact_view.md](case-24b_compact_view.md): `--compact-view` での簡潔ビュー
- [case-23a_structured_json_normal.md](case-23a_structured_json_normal.md): 小規模対応の単一 JSON
