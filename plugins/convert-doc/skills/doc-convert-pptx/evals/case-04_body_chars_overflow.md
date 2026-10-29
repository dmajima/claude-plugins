# Case 04: --max-body-chars 超過 → 継続スライドに自動分割

## 入力

- 入力 MD: 1 つの `## セクション` 配下に 2400 文字を超える本文を配置
- オプション: `--max-body-chars 2400`（デフォルト）

## 期待動作

1. セクション内の本文文字数が `--max-body-chars` を超えた時点で **継続スライド** に分割
2. 最初のスライドには H2 がタイトル帯として表示される
3. 継続スライドのタイトル帯は **連番サフィックス付きの同じ見出し**（2 枚目 `セクション1 (2)`、3 枚目 `セクション1 (3)` …）
4. レイアウトの完全性は保証しない（ベストエフォート）

## 期待出力

- 1 セクションが 2 枚以上のスライドにまたがる
- 各スライドの本文文字数は `--max-body-chars` 以下

## 分岐の根拠

`SKILL.md`「重要な制約」:
> 1 スライドを超える長さのコンテンツは自動で継続スライドに分割するが、レイアウトの完全性は保証しない（ベストエフォート）

`references/scripts/convert-pptx/convert_pptx.py` の `add_content_slide`
（`title = spec.title if idx == 0 else f"{spec.title} ({idx + 1})"`）と
argparse の `--max-body-chars`（デフォルト 2400）。

## 関連ケース

- [case-01_normal_with_h2.md](case-01_normal_with_h2.md): 文字数が閾値以下で 1 セクション 1 スライド
