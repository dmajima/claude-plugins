# Case 05: 図形 + コネクタ → Mermaid flowchart

## 入力

- 入力 PPTX: 1 スライドに以下を配置
  - 角丸四角形 shape_id=10 "開始"
  - ひし形 shape_id=11 "条件分岐"
  - 角丸四角形 shape_id=12 "処理A"
  - 角丸四角形 shape_id=13 "終了"
  - コネクタ: 10 → 11, 11 → 12, 12 → 13
- 図形配置: 縦方向に並ぶ（top 増加, left ほぼ同じ）

## 期待動作

1. テキスト持ち shape は `shapes_meta` に蓄積
2. `_is_connector` がコネクタを判定し `_collect_connector` で `{begin, end}` 抽出
3. `FlowExtractor.build_mermaid` で direction を `TD` と判定（縦並びのため）
4. ひし形は `{ "条件分岐" }` ノードに変換
5. 末尾に Mermaid コードフェンスを出力

## 期待出力（抜粋）

```markdown
\`\`\`mermaid
flowchart TD
    N10["開始"]
    N11{"条件分岐"}
    N12["処理A"]
    N13["終了"]
    N10 --> N11
    N11 --> N12
    N12 --> N13
\`\`\`
```

## 分岐の根拠

`FlowExtractor._infer_direction`:
```python
if x_range > y_range * 1.5:
    return "LR"
return "TD"
```

`FlowExtractor._bracket_for_shape`:
```python
if "DIAMOND" in auto or "FLOWCHART_DECISION" in auto:
    return ("{", "}")
```

## 関連ケース

- [case-06_smartart_mermaid.md](case-06_smartart_mermaid.md): SmartArt 由来
- [case-14_no_mermaid_flag.md](case-14_no_mermaid_flag.md): `--no-mermaid` でテキストにフォールバック
