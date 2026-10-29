# Case 23: 同名テーマの優先解決

## 入力

- 同名テーマ `corp-theme.json` が以下の 2 箇所に存在する状態
  - `${CLAUDE_PLUGIN_ROOT}/assets/pptx-themes/corp-theme.json`（プラグイン共通）
  - ローカルデザインディレクトリ `<designs>/pptx-themes/corp-theme.json`
- ユーザー依頼: 「この MD をスライドにして」（対話モード・テーマ未指定）

## 期待動作

1. 3 箇所の列挙結果を和集合にする際、同名は **スキル > プラグイン共通 > ローカルデザイン** の順で優先する
2. 選択肢には `corp-theme` が **1 件だけ**（プラグイン共通版）現れる（ローカル版は除外）
3. 選択された場合、`--theme` にはプラグイン共通版の絶対パスが渡される

## 期待出力

- 選択 UI に同名テーマが重複表示されない
- プラグイン共通版の配色が適用された PPTX

## 分岐の根拠

`references/theme-selection.md`「テーマの列挙」:
> 同名ファイルは **スキル > プラグイン共通 > ローカルデザイン** の順で優先（下位は選択肢から除外）

## 関連ケース

- [case-13_theme_selection.md](case-13_theme_selection.md): 重複がない通常の選択
