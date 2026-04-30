# Case 05: 「全て不要」選択 → JS なし出力

## 入力

- 入力 MD: 任意
- features.json に機能あり
- ユーザーが除外選択 UI で「全て不要」を選択

## 期待動作

1. 「全て不要」が回答に含まれる場合は **特殊扱い**
2. `--js-features ""` を渡して `convert.py` を実行
3. JS は一切埋め込まれない

## 期待出力

`<script>` タグが存在しない HTML（または空の `<script></script>`）

## 分岐の根拠

`references/css-js-selection.md`「回答の処理」節:
> 「全て不要」が含まれる場合は `--js-features ""` を渡して処理を続行する

## 関連ケース

- [case-04_js_exclude_interactive.md](case-04_js_exclude_interactive.md): 通常の除外選択
- [case-07_non_interactive_full_features.md](case-07_non_interactive_full_features.md): 全機能有効（非対話）
