# Case 13: モノスペースフォント段落 → コードブロック化

## 入力

- 入力 PPTX: 1 スライドのテキストフレームに以下を含む
  - 段落 A（通常フォント Yu Gothic UI）: "通常段落"
  - 段落 B（Consolas）: "let x = 42;"
  - 段落 C（Consolas）: "let y = x + 1;"
  - 段落 D（通常フォント）: "末尾段落"

## 期待動作

1. `_is_monospace_paragraph(B/C)` が True
2. 連続するモノスペース段落は 1 つのコードブロックにまとめる
3. コードブロック内では装飾（太字・斜体）を抑制し、生テキストのみ
4. 段落 D は通常テキストとして出力

## 期待出力

```markdown
# タイトル

通常段落

\`\`\`
let x = 42;
let y = x + 1;
\`\`\`

末尾段落
```

## 分岐の根拠

`convert_from_pptx.py:_convert_text_frame`:
```python
code_buffer: List[str] = []

def flush_code:
    if code_buffer:
        rendered_paragraphs.append("```\n" + "\n".join(code_buffer) + "\n```")
        code_buffer.clear

for paragraph in text_frame.paragraphs:
    if self._is_monospace_paragraph(paragraph):
        raw = "".join((run.text or "") for run in paragraph.runs)
        code_buffer.append(raw)
        continue
    flush_code
```

## 関連ケース

なし
