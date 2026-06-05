# Case 37: `_guess_title_shape` 優先順位 A/B の境界値

## 入力（3 パターン）

| パターン | shape 構成 | 期待される推定経路 |
|---|---|---|
| 37a | top=1_499_999 EMU / height=1_399_999 EMU / 短文「概要」 | A経路マッチ（EMU 閾値ぎりぎり以下）|
| 37b | top=1_500_001 EMU / height=1_400_001 EMU / 短文「概要」 | A経路マッチせず（閾値超過、フォールバック）|
| 37c | 章扉レイアウト + font 28pt（max_font_pt=30pt の 93%）| B経路マッチ（`font >= max * 0.8`）|

- オプション: なし

## 期待動作

1. スライドの placeholder にタイトル shape がない場合に `_guess_title_shape` が起動
2. 優先順位 A: `top <= TOP_THRESHOLD_EMU (1_500_000)` かつ `height <= HEIGHT_THRESHOLD_EMU (1_400_000)` かつ短文（`MAX_TITLE_LEN = 80` 字以下）
3. 優先順位 B: `is_section_cover_layout` かつ `font_size_max_pt >= max_font_pt * 0.8`
4. いずれも該当しない場合は `## スライド<N>` フォールバック

## 期待出力

- 37a: タイトル shape として「概要」が選ばれ `## 概要`
- 37b: A 経路マッチせず `## スライド<N>` または別経路（B が満たされなければフォールバック）
- 37c: B 経路マッチで該当 shape のテキストがタイトル

## 分岐の根拠

`convert_from_pptx.py:_guess_title_shape` の定数:
```python
TOP_THRESHOLD_EMU = 1_500_000
HEIGHT_THRESHOLD_EMU = 1_400_000
MAX_TITLE_LEN = 80
```

EMU 絶対値での比較のため、ratio に換算した case-30 の記述（`top_ratio <= 0.2` 等）は近似であり、実装は EMU で判定する。

## 関連ケース

- [case-02_no_title_placeholder.md](case-02_no_title_placeholder.md): タイトル placeholder 完全欠落
- [case-30_title_estimation_fallback.md](case-30_title_estimation_fallback.md): A/B 経路の代表ケース
