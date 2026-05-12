# Case 04: 画像抽出と相対パス参照

## 入力

- 入力 PPTX: 1 スライドに PNG 画像 1 枚（example.png として埋め込み）
- 出力 MD: `output.md`
- `--images-dir` 省略 → 既定で `output_images/`

## 期待動作

1. `shape.shape_type == MSO_SHAPE_TYPE.PICTURE` を検出
2. `shape.image.blob` をバイト取得
3. `<出力MDディレクトリ>/output_images/slide1_img1.png` に書き出し
4. Markdown には `![<alt>](output_images/slide1_img1.png)` を出力
5. `alt` は picture shape の `descr`（picture description）→ `name` の順で解決

## 期待出力

```markdown
# タイトル

![example](output_images/slide1_img1.png)
```

ファイルツリー:

```
output.md
output_images/
  └── slide1_img1.png
```

## 分岐の根拠

`convert_from_pptx.py:_handle_picture()`:
```python
filename = f"slide{slide_no}_img{img_no}.{ext}"
out_path = self.images_dir / filename
out_path.write_bytes(blob)
rel = out_path.relative_to(self.output_path.parent)
return f"![{alt}]({rel.as_posix()})"
```

## 関連ケース

- [case-10_path_traversal_images_dir.md](case-10_path_traversal_images_dir.md): images-dir のパストラバーサル
- [case-12_max_image_size_overflow.md](case-12_max_image_size_overflow.md): サイズ超過時のフォールバック
