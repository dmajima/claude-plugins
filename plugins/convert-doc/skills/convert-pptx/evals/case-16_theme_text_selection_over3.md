# Case 16: テーマ 3 個以上（テキスト選択に切替）

## 入力

- テーマ JSON が合算で 3 個以上存在する状態（例: `ocean-blue.json` / `dark-console.json` / `warm-corp.json`）
- ユーザー依頼: 「この MD をスライドにして」（対話モード・テーマ未指定）

## 期待動作

1. 「デフォルト + テーマ 3 件」で `AskUserQuestion` の options 上限（4 件・「Other」自動付与のため実質 3 件）を超えると判定する
2. `AskUserQuestion` ではなく **テキストベースの選択** に切り替える（番号付き一覧を提示して回答を待つ）
3. 選択されたテーマの絶対パスを `--theme` に渡して変換する

## 期待出力

- テキスト一覧による選択フローを経て、選択テーマが適用された PPTX

## 分岐の根拠

`references/theme-selection.md`「選択の分岐」:
> 3 以上 | `AskUserQuestion` の options 上限（4 件・「Other」自動付与のため実質 3 件）を超えるため、テキストベースの選択に切り替える

## 関連ケース

- [case-13_theme_selection.md](case-13_theme_selection.md): 1〜2 個（AskUserQuestion）
