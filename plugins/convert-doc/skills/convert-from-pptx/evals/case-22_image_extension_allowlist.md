# Case 22: 画像拡張子 allowlist による正規化

## 入力

- 入力 PPTX: 1 スライドに以下を含む
  - 画像 1: ext = `png`（許可）
  - 画像 2: ext = `svg`（非許可・active content として XSS リスク）
  - 画像 3: ext = `exe`（非許可・実行可能形式）

## 期待動作

1. `_handle_picture()` で `raw_ext = (shape.image.ext or "png").lower()`
2. 許可リスト `{png, jpg, jpeg, gif, bmp, tiff, webp, emf, wmf}` 照合
3. 非許可の場合は `ext = "bin"` に正規化
4. stderr に Warning: `image extension '<raw>' is not in allowlist; normalized to 'bin' on slide <N>`
5. ファイル名は `slide<N>_img<M>.bin` で保存
6. Markdown には `.bin` 拡張子で参照

## 期待出力

```markdown
# タイトル

![image1](slide_images/slide1_img1.png)

![image2](slide_images/slide1_img2.bin)

![image3](slide_images/slide1_img3.bin)
```

- 標準エラー: 2 件の Warning（svg, exe）
- 終了コード: 0

## 分岐の根拠

`convert_from_pptx.py:_handle_picture()`:
```python
raw_ext = (shape.image.ext or "png").lower()
ext = raw_ext if raw_ext in ALLOWED_IMAGE_EXTS else "bin"
if ext != raw_ext:
    print(f"Warning: image extension '{raw_ext}' is not in allowlist; ...", file=sys.stderr)
```

## セキュリティ意義

- `.svg` を後段で HTML レンダリングする場合、`<script>` 要素により XSS 発火のリスクあり
- `.exe` `.bat` `.ps1` 等は実行可能形式として、誤クリック・誤実行による RCE リスクあり
- `.bin` に正規化することで、ファイルマネージャでの誤実行・ブラウザのデフォルト処理を回避する

## 関連ケース

- [case-04_image_extraction.md](case-04_image_extraction.md): 通常の画像抽出
- [case-12_max_image_size_overflow.md](case-12_max_image_size_overflow.md): サイズ超過時の挙動
