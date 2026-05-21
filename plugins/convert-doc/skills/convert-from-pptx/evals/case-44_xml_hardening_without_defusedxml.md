# Case 44: `defusedxml` 非依存での XML 攻撃保護と起動成功

## 入力

- 入力 PPTX: 任意の有効な PPTX（27 スライド規模を想定）
- 出力 MD: `<セッション>/output.md`
- 環境: venv に `defusedxml` がインストールされていない（または存在するが `defusedxml.lxml.monkey_patch_lxml` API が削除済み = `defusedxml>=0.7`）
- 環境変数: 未設定（`CONVERT_FROM_PPTX_ALLOW_UNHARDENED_XML` も不要）

## 期待動作

1. スクリプト起動時に `defusedxml` への依存は無いため、import エラー・AttributeError・exit はいずれも発生しない
2. python-pptx の lxml に対する XML 攻撃保護は、以下の多層防御で代替される:
   - `_validate_pptx()` の **ZIP bomb 検査**（`MAX_TOTAL_UNCOMPRESSED_BYTES = 256 MiB` / `MAX_COMPRESSION_RATIO = 200`）
   - **上限定数**（`MAX_SLIDES` / `MAX_SHAPES_PER_SLIDE` / `MAX_GROUP_DEPTH` / `MAX_TEXT_PER_SHAPE` / `MAX_TOTAL_IMAGE_BYTES` / `MAX_IMAGE_COUNT_PER_PPTX`）
   - スクリプト独自の lxml 解析（SmartArt 等）は `_hardened_xml_parser()` 経由（`resolve_entities=False / no_network=True / load_dtd=False / huge_tree=False`）
3. 通常の変換処理が実行され、Markdown が生成される
4. 終了コード: 0

## 期待出力

- 標準出力:
  ```
  Wrote: <出力MD>
  Images dir: <出力MD basename>_images
  ```
- 標準エラー: 空（defusedxml 関連の Warning / Error は出力されない）
- 終了コード: 0

## 分岐の根拠

`convert_from_pptx.py:27-` の冒頭で defusedxml を import せず、コメントで保護方針を明示している:

```python
# XML 攻撃対策（XXE / Billion Laughs / DTD / external entity, CWE-611 / CWE-776）:
# - 本スクリプト独自の lxml 解析は `_hardened_xml_parser()` で
#   resolve_entities=False / no_network=True / load_dtd=False / huge_tree=False を適用.
# - python-pptx 内部の lxml は直接ハードニングしない代わりに、`_validate_pptx` の
#   ZIP bomb 検査 と 上限定数 で DoS / 巨大エンティティ展開の影響範囲を限定する.
# - 旧コード `defusedxml.lxml.monkey_patch_lxml()` は defusedxml 0.7 で API が
#   削除されたため撤去した（呼び出すと AttributeError → fail-close で起動不能）.
```

## 経緯（回帰防止のメモ）

defusedxml 0.7 以降では `defusedxml.lxml.monkey_patch_lxml` 関数が **完全削除** された。
旧版の起動コードはこれを呼び出して `AttributeError` で `sys.exit(2)` していたため、
**defusedxml==0.7.x が固定されている全環境で本スキルが起動不能**だった
（`Start-Process -RedirectStandardError` 経由では stderr が flush されず「ハング」として観測される）。

本ケースは、旧依存を撤去したあとも XML 攻撃保護が維持されていること、かつ通常の変換が
成功することを保証する。

## 関連ケース

- [case-21a_zip_bomb_total_size.md](case-21a_zip_bomb_total_size.md): ZIP bomb 検査（総展開サイズ）
- [case-21b_zip_bomb_compression_ratio.md](case-21b_zip_bomb_compression_ratio.md): ZIP bomb 検査（圧縮率）
- [case-42a_max_slides_exceeded.md](case-42a_max_slides_exceeded.md): スライド数上限
- [case-42b_max_shapes_exceeded.md](case-42b_max_shapes_exceeded.md): shape 数上限
- [case-42c_max_group_depth_exceeded.md](case-42c_max_group_depth_exceeded.md): グループ再帰深度上限
- [case-42d_max_image_count_exceeded.md](case-42d_max_image_count_exceeded.md): 画像枚数・総量上限
- [case-47_fail_close_stderr_flush.md](case-47_fail_close_stderr_flush.md): fail-close 経路の flush 強制
