# Case 12: `--max-image-size` 超過時のフォールバック

## 入力

- 入力 PPTX: 1 スライドに 10 MiB の高解像度 PNG 画像
- オプション: `--max-image-size 5242880`（既定 5 MiB）

## 期待動作

1. `_handle_picture()` で `len(blob)` を計測
2. `self.max_image_bytes`（5 MiB）を超過
3. stderr に `Warning: image too large (...) > 5242880` を出力
4. バイナリ書き込みをスキップ
5. Markdown には `> 画像（サイズ超過のためバイナリ非保存）: slide=1, name=<...>, size=<N>B` を出力

## 期待出力

```markdown
# タイトル

> 画像（サイズ超過のためバイナリ非保存）: slide=1, name=Picture 1, size=10485760B
```

- 標準エラー: `Warning: image too large (10485760 bytes > 5242880); slide 1 shape 'Picture 1'`
- 終了コード: 0（警告だが正常終了）

## 分岐の根拠

`convert_from_pptx.py:_handle_picture()`:
```python
if size > self.max_image_bytes:
    print(f"Warning: image too large ...", file=sys.stderr)
    return f"> 画像（サイズ超過のためバイナリ非保存）: slide={slide_no}, name={shape.name}, size={size}B"
```

## 関連ケース

- [case-04_image_extraction.md](case-04_image_extraction.md): 通常時の画像抽出
