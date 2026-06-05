# Case 36: 出力 MD パス省略時のデフォルト解決（`<入力>.md`）

## 入力

- 入力 PPTX: `/work/input.pptx`
- 出力 MD: **省略**（位置引数 2 つ目を渡さない）
- オプション: なし

## 期待動作

1. `parse_args` で `args.output = None`
2. `__init__` で `self.output_path = self.input_path.with_suffix(".md")` を適用
3. 解決結果: `/work/input.md`
4. `images_dir` のデフォルトは `/work/input_images/`（output_path の親 + `<stem>_images`）
5. 正常に Markdown を生成
6. 終了コード: 0

## 期待出力

```
/work/input.md
/work/input_images/
```

標準出力: `Wrote: /work/input.md`

## 分岐の根拠

`convert_from_pptx.py:__init__`:
```python
self.output_path = (
    Path(args.output).resolve if args.output else self.input_path.with_suffix(".md")
)
```

`parse_args` の argparse 定義（`output` は `nargs="?"`）:
```python
parser.add_argument(
    "output",
    nargs="?",
    default=None,
    help="Output MD file path (default: <input>.md)",
)
```

省略時に `default=None` → `__init__` で `with_suffix(".md")` フォールバックする境界ケース。

## 関連ケース

- [case-01_normal_with_title.md](case-01_normal_with_title.md): 出力 MD を明示指定する通常ケース
- [case-26_interactive_mode.md](case-26_interactive_mode.md): 対話モードでの出力先確認
