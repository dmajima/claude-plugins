# Case 20: SmartArt 解析失敗時のテキストフォールバック

## 入力

- 入力 PPTX: SmartArt を 1 つ含むが、`dgm:relIds` または data part が解析不能（例: マトリクス型・サイクル型で `cxn[type="parOf"]` のエッジが空）

## 期待動作

1. `_collect_shape()` で `_is_smartart(shape) == True`
2. `_smartart_to_mermaid(shape)` を呼び出すが以下のいずれかで `None` を返す:
   - `relIds` が空
   - `rid_data` が空
   - `data_part` 取得失敗
   - `edges` が空（`parOf` / `presOf` 以外しかない）
   - `etree.fromstring` が `XMLSyntaxError` 等（hardened parser で DTD 拒否）
3. `_smartart_fallback_text(shape)` を呼び出し
4. shape 内の `a:t` を全件抽出して箇条書きに整形

## 期待出力（テキスト抽出成功時）

```markdown
# タイトル

> SmartArt（テキスト抽出）:
- ノードA
- ノードB
- ノードC
```

## 期待出力（テキストもなし）

```markdown
# タイトル

> SmartArt（解析失敗・テキスト抽出不可）
```

## 分岐の根拠

`convert_from_pptx.py:_collect_shape()`:
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

`_smartart_fallback_text()`:
```python
text_nodes = shape.element.findall(f".//{{{NS_A}}}t")
lines = [f"- {node.text.strip()}" for node in text_nodes if node.text and node.text.strip()]
if lines:
    return "> SmartArt（テキスト抽出）:\n" + "\n".join(lines)
return "> SmartArt（解析失敗・テキスト抽出不可）"
```

## 関連ケース

- [case-06_smartart_mermaid.md](case-06_smartart_mermaid.md): Mermaid 化成功
