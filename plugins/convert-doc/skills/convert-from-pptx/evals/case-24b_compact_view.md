# Case 24b: `--compact-view` で人間 / LLM 可読の簡潔ビュー出力

## 入力

- 入力 PPTX: 5 スライド構成の有効な PPTX
- 出力 MD: 未指定（`--json-only` 併用）
- オプション: `--compact-view <セッション>/views/ --json-only`

## 期待動作

1. `_validate_pptx()` で入力 PPTX を検証
2. `export_compact_view()` がスライドごとに 1 ファイル 1 スライドの簡潔ビュー `slide-NN.txt` を出力
3. 各 shape を 1 行で「pos (top, left) / size (h, w) / フォント / プレースホルダ / フラグ / テキスト」形式で表示
4. shape は視覚順（top → left）でソート
5. 終了コード: 0

## 期待出力

```
<セッション>/views/
├── slide-01.txt
├── slide-02.txt
├── slide-03.txt
├── slide-04.txt
└── slide-05.txt
```

各 `slide-NN.txt` の例:
```
=== Slide 1 ===
layout: 'Title Slide'
is_section_cover: false
shape_count: 3, connector_count: 0

[001] top=0.10 left=0.20 h=0.15 w=0.60 ph=CENTER_TITLE auto= font=44.0 color=FFFFFF "プレゼンタイトル"
[002] top=0.55 left=0.20 h=0.10 w=0.60 ph=SUBTITLE auto= font=24.0 color=CCCCCC "サブタイトル"
[003] top=0.92 left=0.85 h=0.04 w=0.10 ph=SLIDE_NUMBER auto= font=10.0 color=999999 [gray] "1"
```

## 分岐の根拠

`convert_from_pptx.py:export_compact_view()` および `_render_compact_slide_view()`:
```python
view_text = self._render_compact_slide_view(slide, emitted, template_texts)
view_path = self.compact_view_dir / f"slide-{emitted:02d}.txt"
with open(view_path, "w", encoding="utf-8", newline="\n") as fh:
    fh.write(view_text)
```

Phase 2 で Claude が Read する際の標準フォーマット（JSON より軽量）。

## 関連ケース

- [case-24a_per_slide_json.md](case-24a_per_slide_json.md): JSON 出力との対比
- [case-23a_structured_json_normal.md](case-23a_structured_json_normal.md): 小規模向け単一 JSON
