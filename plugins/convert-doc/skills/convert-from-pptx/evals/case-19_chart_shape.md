# Case 19: チャート shape の要約出力

## 入力

- 入力 PPTX: 1 スライドに棒グラフのチャートを 1 つ配置
  - 系列 1: "売上"
  - 系列 2: "費用"

## 期待動作

1. `_collect_shape()` で `getattr(shape, "has_chart", False)` が True
2. `_summarize_chart(shape.chart)` を呼び出し
3. `chart.chart_type` の文字列と `chart.series` の各 name を抽出
4. `> チャート: <type> 系列=[...]` 形式の引用ブロックを `kind=chart` として `collected` に追加
5. 通常のテキストフレームには変換されない

## 期待出力（抜粋）

```markdown
# タイトル

> チャート: COLUMN_CLUSTERED (51) 系列=['売上', '費用']
```

> 実際の `chart_type` 文字列は `XL_CHART_TYPE` の repr に従う。

## 分岐の根拠

`convert_from_pptx.py:_collect_shape()`:
```python
if getattr(shape, "has_chart", False) and shape.has_chart:
    block = self._summarize_chart(shape.chart)
    collected.append({"kind": "chart", "shape_id": shape.shape_id, "text": block})
    return
```

`_summarize_chart()`:
```python
return f"> チャート: {type_name} 系列={series_names}"
```

## 関連ケース

なし
