# Case 13: テーマ選択 UI（対話・テーマ 1〜2 個）

## 入力

- `${CLAUDE_PLUGIN_ROOT}/assets/pptx-themes/` またはローカルデザインディレクトリにテーマ JSON が 1〜2 個存在する状態
- ユーザー依頼: 「この MD をスライドにして」（対話モード・テーマ未指定）

## 期待動作

1. `theme-selection.md` の列挙ルールで 3 箇所（skill / plugin / ローカル designs）の `.json` を合算する
2. `AskUserQuestion` で「デフォルト」を先頭にテーマ選択肢を提示する
3. テーマが選択された場合は `--theme "<絶対パス>"` を付与して変換する
4. 「デフォルト」選択時は `--theme` を渡さない（内蔵デフォルトデザイン）
5. 回答受け取り後、確認なしで処理を続行する

## 期待出力

- 選択したテーマの配色・フォントが適用された PPTX（デフォルト選択時は従来デザイン）

## 分岐の根拠

`references/theme-selection.md`「選択の分岐」:
> 1〜2 | `AskUserQuestion` で「デフォルト + 各テーマ」から選択させる

## 関連ケース

- [case-15_theme_zero_default.md](case-15_theme_zero_default.md): テーマ 0 個（UI なし）
- [case-16_theme_text_selection_over3.md](case-16_theme_text_selection_over3.md): 3 個以上（テキスト選択）
- [case-17_theme_noninteractive.md](case-17_theme_noninteractive.md): 非対話呼び出し
