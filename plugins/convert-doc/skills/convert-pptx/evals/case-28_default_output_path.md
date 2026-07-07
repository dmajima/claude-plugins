# Case 28: output 省略時のデフォルト出力パス

## 入力

- 出力パスを省略して実行:

  ```bash
  python convert_pptx.py ./docs/proposal.md
  ```

## 期待動作

1. `args.output` が `None` のため `input_path.with_suffix(".pptx")` が採用される
2. 入力と同ディレクトリ・同名で拡張子だけ `.pptx` に置き換えた絶対パスに出力される

## 期待出力

- `./docs/proposal.pptx` が生成される
- `Generated: <絶対パス>` が標準出力に表示される

## 分岐の根拠

`references/procedures.md`「変換スクリプト実行」:
> 出力先が未指定の場合、入力ファイルと同ディレクトリ・同名で `.pptx` 拡張子

## 関連ケース

- [case-01_normal_with_h2.md](case-01_normal_with_h2.md): 出力パス明示時の標準変換
