# Case 26: H1 が存在しない MD → タイトルスライドなし

## 入力

- H1 を含まない MD（`--title` も未指定）:

  ```markdown
  ## セクション1
  本文1

  ## セクション2
  本文2
  ```

## 期待動作

1. `split_into_slides` で `doc_title` が `None` のままになる
2. `if doc_title:` の分岐によりタイトルスライドが **生成されない**
3. `## セクション` ごとの本文スライドのみが生成される（2 枚）

## 期待出力

- 2 枚構成の PPTX（タイトルスライドなし、各スライドに H2 のタイトル帯）

## 分岐の根拠

`SKILL.md`「スライド分割規則」:
> H1 が 1 つもない | タイトルスライドを生成しない（本文スライドのみ）

`references/scripts/convert-pptx/convert_pptx.py:main`:
```python
if doc_title:
    deck.add_title_slide(doc_title, doc_subtitle)
```

## 関連ケース

- [case-01_normal_with_h2.md](case-01_normal_with_h2.md): H1 ありの標準構成
- [case-02_no_h2_single_slide.md](case-02_no_h2_single_slide.md): H2 がない場合
