# Case 06: SmartArt → Mermaid flowchart

## 入力

- 入力 PPTX: 1 スライドに階層型 SmartArt（組織図）
  - ルート: "本部長"
  - 子: "営業部長", "技術部長"
  - 営業部長の子: "営業1課"

## 期待動作

1. `_is_smartart` が graphic frame の URI に "diagram" を検出
2. `_smartart_to_mermaid` が `dgm:relIds` から data part の rel id を取得
3. data part の XML を `lxml.etree.fromstring` で読み込み
4. `dgm:pt` から modelId とテキストを抽出
5. `dgm:cxn[type="parOf"]` のみエッジ採用
6. ノード ID は modelId の英数字部分を `S` プレフィックス + 20 文字以内
7. `flowchart TD` を出力

## 期待出力（抜粋）

```markdown
\`\`\`mermaid
flowchart TD
    S0["本部長"]
    S1["営業部長"]
    S2["技術部長"]
    S3["営業1課"]
    S0 --> S1
    S0 --> S2
    S1 --> S3
\`\`\`
```

> ノード ID は modelId に依存するため、実際の値は SmartArt のシリアライズに従う。

## 分岐の根拠

`convert_from_pptx.py:_smartart_to_mermaid`:
```python
for connection in data_xml.findall(".//dgm:cxn", namespaces=ns):
    src = connection.get("srcId")
    dst = connection.get("destId")
    ctype = connection.get("type", "parOf")
    if ctype not in ("parOf", "presOf"):
        continue
```

## 関連ケース

- [case-05_flowchart_mermaid.md](case-05_flowchart_mermaid.md): 図形 + コネクタ
- 解析できない構造は `_smartart_fallback_text` で `> SmartArt（テキスト抽出）:` 形式に
