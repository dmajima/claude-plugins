# Case 08: 非表示スライド（`--include-hidden`）

## 入力

- 入力 PPTX: 3 スライド構成
  - スライド 1: 通常 "表示"
  - スライド 2: `show="0"` 属性付き "非表示"
  - スライド 3: 通常 "表示2"

## 期待動作（オプション指定なし）

1. スライド 2 は `_is_hidden(slide) == True` で除外
2. 出力には 2 スライドのみ含まれる
3. 出力スライド番号は連番（スライド 1 → H1、スライド 3 → `## 表示2`）

## 期待動作（`--include-hidden` 指定時）

1. スライド 2 も `_is_hidden` でも `include_hidden=True` のため出力対象
2. 出力には 3 スライド分含まれる
3. スライド番号は連番（1, 2, 3）

## 期待出力（指定なし）

```markdown
# 表示

## 表示2
```

## 期待出力（`--include-hidden`）

```markdown
# 表示

## 非表示

## 表示2
```

## 分岐の根拠

`convert_from_pptx.py:convert()`:
```python
for slide in presentation.slides:
    if self._is_hidden(slide) and not self.include_hidden:
        continue
    emitted_slide_no += 1
```

`_is_hidden()`:
```python
return slide.element.get("show") == "0"
```

## 関連ケース

なし
