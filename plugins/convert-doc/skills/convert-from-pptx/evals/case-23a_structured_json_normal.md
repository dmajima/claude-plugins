# Case 23a: `--structured-json` + `--json-only` 正常系（Phase 1 JSON 出力）

## 入力

- 入力 PPTX: 3 スライド構成の有効な PPTX
- 出力 MD: 未指定（`--json-only` のため不要）
- オプション: `--structured-json <セッション>/structured.json --json-only`

## 期待動作

1. `_validate_pptx()` で入力 PPTX を検証（マジック / 拡張子 / ZIP bomb / Content_Types）
2. `export_structured_json()` が全 shape を構造化 JSON に dump（装飾フィルタ未適用）
3. `<セッション>/structured.json` に `metadata` + `slides[]` を書き出し
4. `--json-only` 指定のため Markdown 直接生成はスキップ
5. 画像は `<basename>_images/` に同時抽出
6. 終了コード: 0

## 期待出力

```jsonc
{
  "metadata": {
    "input_path": "...",
    "slide_count": 3,
    "slide_width_emu": 12192000,
    "slide_height_emu": 6858000,
    "images_dir": "...",
    "template_decoration_texts": [...],
    "schema_version": "1.0"
  },
  "slides": [
    {
      "slide_no": 1,
      "layout_name": "...",
      "is_section_cover_layout": false,
      "shapes": [ /* 全 shape の構造データ */ ],
      "connectors": [],
      "notes": ""
    },
    ...
  ]
}
```

## 分岐の根拠

`convert_from_pptx.py:export_structured_json()`:
```python
document = {
    "metadata": { ... "schema_version": "1.0" },
    "slides": slides_data,
}
with open(self.structured_json_path, "w", encoding="utf-8", newline="\n") as fh:
    json.dump(document, fh, ensure_ascii=False, indent=2)
```

`main()` の `--json-only` 分岐で Markdown 生成をスキップする。

## 関連ケース

- [case-23b_json_only_alone.md](case-23b_json_only_alone.md): `--json-only` 単独指定
- [case-24a_per_slide_json.md](case-24a_per_slide_json.md): 中規模対応分割
