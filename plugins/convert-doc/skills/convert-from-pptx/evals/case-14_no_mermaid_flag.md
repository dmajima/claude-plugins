# Case 14: `--no-mermaid` 指定時の挙動

## 入力

- 入力 PPTX: case-05 と同じ図形 + コネクタ構成（フロー図）
- オプション: `--no-mermaid`

## 期待動作

1. `_convert_slide()` で `self.no_mermaid == True` のため `FlowExtractor.build_mermaid()` は呼ばれない
2. SmartArt も `_smartart_to_mermaid()` をスキップし `_smartart_fallback_text()` のみ実行
3. 通常の各図形のテキストは個別の段落として `_convert_text_frame()` 経由で出力される
4. コネクタはテキスト出力されない（接続情報は失われる）

## 期待出力（抜粋）

```markdown
# タイトル

開始

条件分岐

処理A

終了
```

（Mermaid フェンスは含まれない）

## 分岐の根拠

`convert_from_pptx.py:_convert_slide()`:
```python
if not self.no_mermaid:
    extractor = FlowExtractor(shapes_meta, connectors)
    mermaid_md = extractor.build_mermaid()
```

`_collect_shape()`:
```python
if self._is_smartart(shape):
    mermaid = None
    if not self.no_mermaid:
        mermaid = self._smartart_to_mermaid(shape)
    if mermaid:
        collected.append({"kind": "mermaid", ...})
    else:
        collected.append({"kind": "smartart", "text": self._smartart_fallback_text(shape)})
```

## 関連ケース

- [case-05_flowchart_mermaid.md](case-05_flowchart_mermaid.md): デフォルト（Mermaid 有効）
- [case-06_smartart_mermaid.md](case-06_smartart_mermaid.md): SmartArt のデフォルト挙動
