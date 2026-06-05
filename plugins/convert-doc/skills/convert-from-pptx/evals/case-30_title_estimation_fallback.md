# Case 30: タイトル代替推定（`_guess_title_shape` の優先順位 A/B 経路）

## 入力

- 入力 PPTX: 2 スライド構成
  - スライド 1: `placeholder.type` が `TITLE` の shape が **存在しない**。代わりに最上部・横長・短文の TextBox（top_ratio=0.1, height_ratio=0.08, text="導入") がある
  - スライド 2: 章扉レイアウト（`is_section_cover_layout=true`）で、中央配置の大型テキスト（font_size_max_pt がスライド内最大）がタイトル
- オプション: なし

## 期待動作

1. スライド 1: `_guess_title_shape` の優先順位 A（最上部・薄い帯・短文）で TextBox をタイトル推定 → `## 導入`
2. スライド 2: `_guess_title_shape` の優先順位 B（章扉中央・最大フォントに近い大型テキスト）でタイトル推定
3. いずれも代替推定パスを通り、placeholder ベースの推定にフォールバックしない
4. 終了コード: 0

## 期待出力

```markdown
## 導入

導入本文...

## 第 2 章のタイトル
```

（スライド 1 は `--no-first-slide-as-title` がない場合は `# 導入` になるが、本ケースは複数スライド経路を検証する目的のため `##` 表記で記載）

## 分岐の根拠

`convert_from_pptx.py:_guess_title_shape` の閾値は **EMU 絶対値** で実装されている:
- 優先順位 A: `top <= TOP_THRESHOLD_EMU (1_500_000)` かつ `height <= HEIGHT_THRESHOLD_EMU (1_400_000)` の短文（`MAX_TITLE_LEN = 80` 文字以下）
- 優先順位 B: `is_section_cover_layout` かつ `font_size_max_pt >= max_font_pt * 0.8`

EMU 絶対値の理由: 標準スライド寸法（9144000 × 6858000 EMU、ワイドスクリーン 12192000 × 6858000 EMU）でスライド高さに対する比率はおおむね top 約 0.22 / height 約 0.20 に相当するが、レイアウトに依存しない一定の絶対値判定を採用している。

`json-schema.md` 節 2.1 のタイトル推定ガイドラインに対応するが、実装は ratio ではなく EMU で判定する点に注意。

## 関連ケース

- [case-01_normal_with_title.md](case-01_normal_with_title.md): placeholder ベースのタイトル
- [case-02_no_title_placeholder.md](case-02_no_title_placeholder.md): タイトル placeholder 完全欠落
- [case-18_no_first_slide_as_title.md](case-18_no_first_slide_as_title.md): 1 枚目の H1 / H2 切替
