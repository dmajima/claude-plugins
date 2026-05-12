# Case 10: `--images-dir` のパストラバーサル拒否

## 入力

- 入力 PPTX: 任意の有効な PPTX
- 出力 MD: `/tmp/out/output.md`
- `--images-dir`: `../../../etc/images`（出力 MD の親ディレクトリ外へ脱出）

## 期待動作

1. `_resolve_images_dir()` で `candidate.relative_to(base)` を実行
2. base = `/tmp/out/` 配下に解決できない → `ValueError` を raise
3. メッセージ: `images-dir must be under output MD directory (path traversal blocked): <絶対パス>`
4. stderr にエラー出力し `sys.exit(1)`

## 期待出力

- 標準エラー: `Error: images-dir must be under output MD directory (path traversal blocked): /etc/images`
- 終了コード: 1
- 画像は抽出されない
- 出力 MD は生成されない

## 分岐の根拠

`convert_from_pptx.py:_resolve_images_dir()`:
```python
try:
    candidate.relative_to(base)
except ValueError as exc:
    raise ValueError(
        f"images-dir must be under output MD directory (path traversal blocked): {candidate}"
    ) from exc
```

`main()`:
```python
except ValueError as exc:
    print(f"Error: {exc}", file=sys.stderr)
    return 1
```

## 関連ケース

- [case-04_image_extraction.md](case-04_image_extraction.md): 正常な画像抽出
