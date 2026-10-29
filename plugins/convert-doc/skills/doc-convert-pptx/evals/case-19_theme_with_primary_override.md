# Case 19: テーマと --primary-color の併用

## 入力

- ユーザー依頼: 「dark-console テーマで、基調色だけ #8B0000 にしてスライド化して」

## 期待動作

1. テーマ `dark-console.json` を解決して `--theme` に渡す
2. 併せて `--primary-color "#8B0000"` を渡す
3. 変換結果では **primary のみ `#8B0000` が優先** され、テーマの他の値（code_bg / syntax_palette 等）はそのまま適用される
4. テーマが `composition`（構図）を持ち、shapes / title の `color` に色トークン `"primary"` を使っている場合も、
   その部分は `#8B0000` で描画される（トークンは描画時に解決されるため CLI 上書きが構図にも波及する。
   hex 直接指定 `"#..."` の要素は影響を受けない）

## 期待出力

- タイトル帯・見出し・表ヘッダが `#8B0000`、コードブロックは dark-console の暗色のままの PPTX
- composition 付きテーマの場合、構図内の `"primary"` トークン要素（例: 下端帯）も `#8B0000` になる

## 分岐の根拠

`references/theme-selection.md`「`--primary-color` との併用」:
> `--primary-color` はテーマの `primary` より優先される（テーマの他の色はそのまま）。
> ユーザーが「テーマ X で、基調色だけ #123456」のような依頼をした場合は両方を渡す

`SKILL.md`「オプション」:
> `--primary-color` … テーマ指定より優先

## 関連ケース

- [case-07_invalid_primary_color.md](case-07_invalid_primary_color.md): 不正な --primary-color の拒否
- [case-18_theme_named_resolution.md](case-18_theme_named_resolution.md): テーマ名明示の解決
