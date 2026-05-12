# Case 18: `--no-first-slide-as-title` 指定時の 1 枚目挙動

## 入力

- 入力 PPTX: 2 スライド構成
  - スライド 1: タイトル "提案資料"
  - スライド 2: タイトル "概要"
- オプション: `--no-first-slide-as-title`

## 期待動作

1. コンストラクタで `self.first_slide_as_title = not bool(args.no_first_slide_as_title)` → `False`
2. スライド 1 の条件分岐で `slide_no == 1 and self.first_slide_as_title` が False
3. スライド 1 も `## 提案資料`（H2）として出力
4. ドキュメント全体に H1 が一つも存在しない

## 期待出力

```markdown
## 提案資料

## 概要
```

## 分岐の根拠

`convert_from_pptx.py:__init__()`:
```python
self.first_slide_as_title = not bool(args.no_first_slide_as_title)
```

`_convert_slide()`:
```python
if slide_no == 1 and self.first_slide_as_title:
    heading = f"# {title or 'タイトル'}"
else:
    heading = f"## {title or f'スライド{slide_no}'}"
```

## 関連ケース

- [case-01_normal_with_title.md](case-01_normal_with_title.md): デフォルト（H1）
