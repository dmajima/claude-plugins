# Case 07: スピーカーノート（`--include-notes`）

## 入力

- 入力 PPTX: 1 スライド
  - 本文: "本文テキスト"
  - スピーカーノート: "発表者用メモ\n二行目"
- オプション: `--include-notes`

## 期待動作

1. 各スライドの本文ブロック生成後、`include_notes=True` のため `_extract_notes` を呼び出し
2. `notes_slide.notes_text_frame.text` を取得
3. `> [!NOTE]` で開始し、各行に `> ` プレフィックスを付与

## 期待出力

```markdown
# タイトル

本文テキスト

> [!NOTE]
> 発表者用メモ
> 二行目
```

## オプション未指定時

`--include-notes` を指定しない場合は `_extract_notes` 自体が呼ばれず、ノートは Markdown に含まれない。

## 分岐の根拠

`convert_from_pptx.py:_convert_slide`:
```python
if self.include_notes:
    notes = self._extract_notes(slide)
    if notes:
        body_blocks.append(notes)
```

## 関連ケース

なし
