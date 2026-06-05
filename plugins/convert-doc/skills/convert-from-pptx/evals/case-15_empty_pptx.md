# Case 15: 空 PPTX（スライド 0 枚）

## 入力

- 入力 PPTX: スライドが 1 枚も含まれない有効な PPTX
- オプション: なし

## 期待動作

1. `_validate_pptx` は通過（ZIP として正当・Content_Types に presentationml あり）
2. `for slide in presentation.slides:` がループしない
3. `markdown_chunks` は空のままで `body = ""`
4. 末尾の `\n` のみが書き出される
5. 画像ディレクトリは作成されるが空
6. 終了コード: 0

## 期待出力

ファイル内容: 改行 1 文字のみ
```
```

## 分岐の根拠

`convert_from_pptx.py:convert`:
```python
for slide in presentation.slides:
    if self._is_hidden(slide) and not self.include_hidden:
        continue
    ...
body = "\n\n".join(markdown_chunks)
if not body.endswith("\n"):
    body += "\n"
```

## 関連ケース

なし
