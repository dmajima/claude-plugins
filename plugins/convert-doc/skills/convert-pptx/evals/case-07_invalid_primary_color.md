# Case 07: 不正な --primary-color 指定 → ArgumentTypeError

## 入力

- 入力 MD: 任意
- オプション: `--primary-color "purple"`（HEX 形式でない）または `--primary-color "#xyz"`

## 期待動作

1. `hex_to_rgb` が呼ばれる際、入力が `^#?[0-9A-Fa-f]{3}([0-9A-Fa-f]{3})?$` に一致しない
2. `argparse.ArgumentTypeError("invalid hex color: 'purple' (expected '#RGB' or '#RRGGBB')")` を発生
3. argparse が usage メッセージを表示して `sys.exit(2)`（argparse 標準動作）

## 期待出力

- 標準エラー: `error: argument --primary-color: invalid hex color: ...`
- 終了コード: 2
- 出力 PPTX: 生成されない

## 分岐の根拠

`references/scripts/convert-pptx/convert_pptx.py` の 2 関数構成
（`_parse_hex_color` が `ValueError` を送出し、argparse type= ラッパー `hex_to_rgb` が
`ArgumentTypeError` に変換して exit 2 を維持する）:

```python
_HEX_COLOR_RE = re.compile(r"^#?[0-9A-Fa-f]{3}([0-9A-Fa-f]{3})?$")

def _parse_hex_color(hex_str) -> RGBColor:
    if not isinstance(hex_str, str) or not _HEX_COLOR_RE.match(hex_str):
        raise ValueError(...)
    ...

def hex_to_rgb(hex_str: str) -> RGBColor:
    try:
        return _parse_hex_color(hex_str)
    except ValueError as e:
        raise argparse.ArgumentTypeError(str(e)) from e
```

## 関連ケース

なし（バリデーション）
