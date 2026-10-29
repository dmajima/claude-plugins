# Case 04: features.json に機能あり → 除外を AskUserQuestion で選択

## 入力

- 入力 MD: 任意
- `${CLAUDE_SKILL_DIR}/assets/js/features.json` に機能 1-2 個が登録されている例:

```json
{
  "features": [
    {"name": "ライトボックス", "file": "lightbox.js", "description": "..."},
    {"name": "目次トグル",     "file": "toc-toggle.js", "description": "..."}
  ]
}
```

## 期待動作

1. `AskUserQuestion` を以下の引数で呼び出す:
   - `question`: `"除外するJS機能を選択してください。（何も選択しない → 全機能有効）"`
   - `header`: `"JS機能"`
   - `multiSelect`: `true`
   - `options`: 各機能 + 末尾に `{ label: "全て不要", description: "JSを一切埋め込まない" }`
2. ユーザーが「ライトボックス」のみ選択した場合:
   - 除外: `lightbox.js`
   - 残り: `toc-toggle.js`
   - `--js-features toc-toggle.js` を渡す
3. ユーザーが何も選択しなかった場合: 全機能のファイル名をカンマ結合して `--js-features lightbox.js,toc-toggle.js`

## 期待出力

- 全機能有効: 全 JS ファイルが `<script>` タグで結合・埋め込まれた HTML
- 一部除外: 残り機能のみ埋め込まれた HTML

## 分岐の根拠

`references/css-js-selection.md`「呼び出し方針」節（JS 機能）:
> features.json に 1 つ以上の機能が登録されている場合は AskUserQuestion ツールで確認する

## 関連ケース

- [case-05_js_all_disabled.md](case-05_js_all_disabled.md): 「全て不要」選択時
- [case-06_js_features_over3_text_select.md](case-06_js_features_over3_text_select.md): 3 機能以上
- [case-07_non_interactive_full_features.md](case-07_non_interactive_full_features.md): 非対話モード
