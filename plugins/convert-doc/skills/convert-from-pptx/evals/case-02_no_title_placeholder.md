# Case 02: タイトル placeholder が存在しないスライド

## 入力

- 入力 PPTX: 1 スライド構成
  - タイトル placeholder なし
  - 本文テキストボックス: "メモのみ"

## 期待動作

1. `slide.shapes.title` が None → タイトル抽出 None
2. 1 枚目かつ `first_slide_as_title=True` のため `# タイトル`（デフォルト文言）
3. 本文 "メモのみ" が後続に段落として配置

## 期待出力

```markdown
# タイトル

メモのみ
```

## 分岐の根拠

`convert_from_pptx.py:_convert_slide`:
```python
if slide_no == 1 and self.first_slide_as_title:
    heading = f"# {title or 'タイトル'}"
```

`_extract_title` で title 取得失敗時に None を返す → デフォルト文言にフォールバック。

## 関連ケース

- [case-01_normal_with_title.md](case-01_normal_with_title.md): タイトルありの標準ケース
