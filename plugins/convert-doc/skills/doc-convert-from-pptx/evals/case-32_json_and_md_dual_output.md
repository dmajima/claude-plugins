# Case 32: `--structured-json` 指定（`--json-only` なし）→ JSON + Markdown の同時出力

## 入力

- 入力 PPTX: 3 スライド構成の有効な PPTX
- 出力 MD: `<セッション>/output.md`
- オプション: `--structured-json <セッション>/structured.json`（`--json-only` は **未指定**）

## 期待動作

1. `_validate_pptx` で入力 PPTX を検証
2. `export_structured_json` で `structured.json` を出力 → `wrote_anything = True`
3. `wrote_anything = True` かつ `converter.json_only = False` のため `if converter.json_only: return 0` ガードが不成立
4. そのまま `converter.convert` に進み、`output.md` も生成
5. 画像は `<basename>_images/` に共通抽出
6. 終了コード: 0

## 期待出力

```
<セッション>/structured.json
<セッション>/output.md
<セッション>/output_images/
```

標準出力:
```
Wrote JSON: <セッション>/structured.json
Images dir: <セッション>/output_images
Wrote: <セッション>/output.md
Images dir: <セッション>/output_images
```

## 分岐の根拠

`convert_from_pptx.py:main` のフロー:
```python
if converter.structured_json_path is not None:
    json_path = converter.export_structured_json
    print(f"Wrote JSON: {json_path}")
    wrote_anything = True
# ... (per-slide / compact-view も同様)
if wrote_anything:
    print(f"Images dir: {converter.images_dir}")
    if converter.json_only:
        return 0  # ← --json-only ありならここで終了
# --json-only 無し → そのまま MD 直接出力に進む
output_path = converter.convert
```

このケースは `--json-only` なし + `--structured-json` ありで「両方出力」のパスを検証する。

## 関連ケース

- [case-23a_structured_json_normal.md](case-23a_structured_json_normal.md): `--json-only` あり（JSON のみ）
- [case-23b_json_only_alone.md](case-23b_json_only_alone.md): `--json-only` 単独（MD 生成にフォールバック）
