# Case 23b: `--json-only` 単独指定（出力先 JSON 未指定時の自動フォールバック）

## 入力

- 入力 PPTX: 任意の有効な PPTX（3 スライド）
- 出力 MD: `output.md`
- オプション: `--json-only`（`--structured-json` / `--per-slide-json` / `--compact-view` のいずれも未指定）

## 期待動作

1. `_validate_pptx()` で入力 PPTX を検証
2. `structured_json_path` / `per_slide_json_dir` / `compact_view_dir` がいずれも `None`
3. `wrote_anything = False` のまま 3 つの `if converter.<dir>_path is not None` ブロックを通過
4. `if wrote_anything: ... if converter.json_only: return 0` のガードが不成立（`wrote_anything=False`）のため通常の Markdown 直接出力に進む
5. `--json-only` フラグは「JSON 出力先指定がない場合は無視される」設計
6. 終了コード: 0

## 期待出力

- `output.md` が生成される（通常の Phase 1+2 経由なしの Python 単独 Markdown）
- JSON / per-slide / compact-view は出力されない
- 標準出力: `Wrote: <output_path>` / `Images dir: <images_dir>`
- 終了コード: 0

## 分岐の根拠

`convert_from_pptx.py:main()` の制御フロー（実装事実）:
```python
wrote_anything = False
if converter.structured_json_path is not None:
    ...; wrote_anything = True
if converter.per_slide_json_dir is not None:
    ...; wrote_anything = True
if converter.compact_view_dir is not None:
    ...; wrote_anything = True
if wrote_anything:
    print(f"Images dir: {converter.images_dir}")
    if converter.json_only:
        return 0
# JSON 系オプション未指定 or --json-only 無し → 従来の Markdown 直接出力
output_path = converter.convert()
```

`--json-only` 単独指定は出力先 JSON が無いため `wrote_anything=False` のまま通常 MD 生成に到達する。

## 関連ケース

- [case-23a_structured_json_normal.md](case-23a_structured_json_normal.md): `--structured-json` + `--json-only` 正常系
- [case-32_json_and_md_dual_output.md](case-32_json_and_md_dual_output.md): `--json-only` なしでの JSON + MD 同時出力
