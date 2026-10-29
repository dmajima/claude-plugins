# Case 09: layout_in 過大値によるレイアウト崩れの検知

## 入力

- ユーザー要望を反映したテーマ JSON の `layout_in` が過大（例: `title_band_height: 6.5`。
  スライド高 7.5in に対して本文領域がほぼ消える値）

## 期待動作

1. `validate_theme.py` 自体はスキーマ上有効なため PASS する（正の有限数）
2. **サンプル変換（実行フロー 7）で必ず検知する**: `convert_pptx.py` が stderr に
   `Warning: N block(s) did not fit on a slide and were not rendered (check layout_in / font_sizes_pt theme values)` を出力する
3. 警告を検知したら配置に進まず、`theme-schema.md` のガイドライン
   （デフォルトから大きく動かさない）に従い `layout_in` を修正して再変換する
4. 警告が出なくなってから配置する

## 期待出力

- 本文ブロックが欠落しないテーマ JSON のみが配置される
- 警告が残ったまま配置された形跡がない

## 分岐の根拠

`references/theme-schema.md`「layout_in」:
> 過大な値（例: `title_band_height` をスライド高 7.5in に近づける）は本文の縦領域を消し、収まらないブロックが描画されない（その場合スクリプトが stderr に `Warning: N block(s) did not fit ...` を出力する）

`references/procedures.md`「トラブルシューティング」:
> サンプル変換でスライドがはみ出す → `layout_in.title_band_height` / `content_padding` の変更が原因

## 関連ケース

- [case-03_schema_error_retry.md](case-03_schema_error_retry.md): スキーマレベルで検知できるエラー
- [case-08_dark_theme_contrast.md](case-08_dark_theme_contrast.md): 検証は通るが品質調整が必要な配色ケース
