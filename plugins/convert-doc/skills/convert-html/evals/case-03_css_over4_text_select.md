# Case 03: CSS が合算 4 ファイル以上 → テキストベース選択

## 入力

- 入力 MD: 任意
- CSS ファイルが合算で 4 つ以上存在（プラグイン共通 + スキル固有）

## 期待動作

1. `AskUserQuestion` を **呼び出さない**（options 上限 4 件 + Other 自動付与で実質 3 件しか提示できないため）
2. 代わりにテキストベースの選択提示:
   - 検出した CSS ファイル名を番号付きリストで列挙
   - ユーザーに番号またはファイル名を返答してもらう
3. 入力されたファイル名を絶対パスに解決して `--css-template "<絶対パス>"` を渡す

## 期待出力

選択されたファイルの CSS 内容が埋め込まれた HTML

## 分岐の根拠

`references/css-js-selection.md`「制約」節:
> `AskUserQuestion` の options は最大 4 件（「Other」は自動付与のため実質 3 件）。CSS ファイルが 4 件以上の場合はテキストベースの選択に切り替える

## 関連ケース

- [case-02_css_multi_interactive.md](case-02_css_multi_interactive.md): 2-3 ファイル（AskUserQuestion）
