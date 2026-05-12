# Case 08: 入力 MD ファイルが存在しない

## 入力

- 入力 MD: 存在しないパス（例: `./does_not_exist.md`）

## 期待動作

1. `convert.py` 内で `Path(input).exists()` チェックが失敗
2. stderr に `Error: Input file not found: <path>` を出力
3. `sys.exit(1)` で終了（戻り値 1）

## 期待出力

- 標準出力: なし
- 標準エラー: `Error: Input file not found: <path>`
- 終了コード: 1
- 出力 HTML ファイル: 生成されない

## 分岐の根拠

`references/scripts/convert-html/convert.py:main()` の入力検証:
> `if not input_path.exists(): print(...); sys.exit(1)`

## 関連ケース

なし（エラー系）
