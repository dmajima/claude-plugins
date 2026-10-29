# Case 27: input 位置引数の省略 → exit 2

## 入力

- コマンドライン引数なしで実行（`--dump-default-theme` も未指定）:

  ```bash
  python convert_pptx.py
  ```

## 期待動作

1. `--dump-default-theme` が指定されていないため、`input` の必須チェックに進む
2. `parser.error("the following arguments are required: input")` が発火する
3. argparse 標準動作として usage メッセージを stderr に出力し **exit 2** で終了する
   （入力ファイル不在の exit 1（[case-06](case-06_input_not_found.md)）とは別経路）

## 期待出力

- 標準エラー: usage 行 + `error: the following arguments are required: input`
- 終了コード: 2
- 出力 PPTX: 生成されない

## 分岐の根拠

`references/scripts/convert-pptx/convert_pptx.py:main`:
```python
if not args.input:
    parser.error("the following arguments are required: input")
```

## 関連ケース

- [case-06_input_not_found.md](case-06_input_not_found.md): 引数はあるがファイルが存在しない（exit 1）
