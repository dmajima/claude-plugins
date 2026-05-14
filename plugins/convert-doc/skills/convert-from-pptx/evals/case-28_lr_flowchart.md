# Case 28: フロー図 `LR`（横方向）Mermaid 出力

## 入力

- 入力 PPTX: 1 スライドに 3 つの図形が **横方向に並ぶ** + コネクタで連結
  - shape A (left=0.1, top=0.5)
  - shape B (left=0.4, top=0.5)
  - shape C (left=0.7, top=0.5)
  - A → B, B → C のコネクタ
- オプション: なし（Mermaid 化はデフォルト ON）

## 期待動作

1. `FlowExtractor.build_mermaid()` を起動
2. `_infer_direction()` が `x_range > y_range * 1.5` を満たすため `"LR"` を返す
3. Mermaid フローチャートを `flowchart LR` で生成
4. 終了コード: 0

## 期待出力

Markdown 内に以下の Mermaid ブロック:

````markdown
```mermaid
flowchart LR
    N2["shape A"]
    N3["shape B"]
    N4["shape C"]
    N2 --> N3
    N3 --> N4
```
````

## 分岐の根拠

`convert_from_pptx.py:FlowExtractor._infer_direction()`:
```python
x_range = max(xs) - min(xs)
y_range = max(ys) - min(ys)
if x_range > y_range * 1.5:
    return "LR"
return "TD"
```

## 関連ケース

- [case-05_flowchart_mermaid.md](case-05_flowchart_mermaid.md): `TD`（縦方向）の通常ケース
- [case-14_no_mermaid_flag.md](case-14_no_mermaid_flag.md): `--no-mermaid` で抑制
