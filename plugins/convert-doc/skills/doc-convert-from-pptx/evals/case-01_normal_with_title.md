# Case 01: 標準変換（タイトル placeholder あり・複数スライド）

## 入力

- 入力 PPTX: 3 スライド構成
  - スライド 1: タイトル placeholder = "提案資料"
  - スライド 2: タイトル placeholder = "概要", 本文 placeholder に箇条書き 3 件
  - スライド 3: タイトル placeholder = "詳細"
- オプション: なし（デフォルト）

## 期待動作

1. スライド 1 を `# 提案資料` として出力（`--no-first-slide-as-title` 未指定のため H1）
2. スライド 2 を `## 概要` として出力、配下に `- 箇条書き1` 形式で 3 件
3. スライド 3 を `## 詳細` として出力
4. 画像は無し → `<basename>_images/` は作成されるが空
5. 終了コード: 0

## 期待出力

```markdown
# 提案資料

## 概要

- 箇条書き1
- 箇条書き2
- 箇条書き3

## 詳細
```

## 分岐の根拠

`SKILL.md` の「スライド→Markdown の対応規則」表:
> 1 枚目のタイトル placeholder → `# <タイトル>`
> 2 枚目以降のタイトル placeholder → `## <タイトル>`

`convert_from_pptx.py:_convert_slide`:
```python
if slide_no == 1 and self.first_slide_as_title:
    heading = f"# {title or 'タイトル'}"
else:
    heading = f"## {title or f'スライド{slide_no}'}"
```

## 関連ケース

- [case-02_no_title_placeholder.md](case-02_no_title_placeholder.md): タイトルなし
- [case-14_no_mermaid_flag.md](case-14_no_mermaid_flag.md): Mermaid 化抑制
