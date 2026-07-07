# Case 15: composition の変換時警告（title_band_height 併記 / "sym" 負値解決）

## 入力

検証（`validate_theme.py`）は PASS するが、変換時に警告が出る composition 付きテーマ。2 系統:

1. `composition.content_header` を上書きし、かつ同じテーマ JSON に既定値（0.9）と異なる
   `layout_in.title_band_height`（例: 1.2）を明示
2. `shapes[]` に `x` が過大な `"sym"` 幅の矩形（例: 16:9 で `{"x": 8.0, "w": "sym", ...}` → 実効幅 13.333 − 16.0 < 0）

## 期待動作

1. 系統 1: テーマ読込時に stderr へ警告が出る（変換自体は成功する）
   - `Warning: this theme overrides composition.content_header, so layout_in.title_band_height is not used ...`
   - 対応: `layout_in.title_band_height` を削除するか、既定構図に戻すかの片寄せをユーザーに提案する
2. 系統 2: サンプル変換時に該当シェイプが描画スキップされ stderr へ警告が出る（変換自体は成功する）
   - `Warning: composition shape at x=8.0, y=... resolves to a non-positive size ... and was skipped`
   - 対応: `x` を小さくするか実数幅に変更して再変換し、警告が消えたことを確認する
3. いずれも **警告を解消してから配置する**（警告付きのまま無言で配置しない）

## 期待出力

- 警告の原因と対処をユーザーに報告した記録
- 最終配置版のサンプル変換では該当警告が出ていない

## 分岐の根拠

`references/theme-schema.md`「layout_in（レイアウト寸法・inch）」:
> `composition.content_header` を上書きしたテーマに `layout_in.title_band_height` を併記すると、「参照されない」旨の警告が stderr に出る

`references/theme-schema.md`「shapes[]」:
> `"sym"` は `x` が大きいと解決結果が負になり得る（...）描画時に幅・高さが 0 以下となった要素はスキップされ stderr に警告が出る（安全網）

`references/procedures.md`「トラブルシューティング」:
> 変換時 `Warning: ... title_band_height is not used` / 変換時 `Warning: composition shape ... was skipped`

## 関連ケース

- [case-09_layout_overflow_warning.md](case-09_layout_overflow_warning.md): 縦領域不足による did-not-fit 警告（`content_top` 過大時も同じ安全網）
- [case-13_composition_theme.md](case-13_composition_theme.md): composition の正常系
- [case-14_composition_schema_errors.md](case-14_composition_schema_errors.md): 検証段階で FAIL する系
