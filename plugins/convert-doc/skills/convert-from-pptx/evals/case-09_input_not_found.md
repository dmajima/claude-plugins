# Case 09: 入力 PPTX ファイルが存在しない

## 入力

- 入力 PPTX: 存在しないパス（例: `./missing.pptx`）

## 期待動作

1. `Path(args.input).exists()` が False
2. stderr に `Error: Input file not found: <path>` を出力
3. `sys.exit(1)` で終了

## 期待出力

- 標準エラー: `Error: Input file not found: <path>`
- 終了コード: 1
- 出力 MD: 生成されない
- 画像ディレクトリ: 作成されない

## 分岐の根拠

`convert_from_pptx.py:main()`:
```python
if not input_path.exists():
    print(f"Error: Input file not found: {input_path}", file=sys.stderr)
    return 1
```

## 起動経路についての注記

本ケースは `convert_from_pptx.py` 単独実行時の挙動を記述しているが、実運用では
`run_via_job.ps1` ラッパー経由起動が必須（[`../references/procedures.md`](../references/procedures.md) 参照）。
ラッパー経由の場合の挙動:

- Python が `sys.exit(1)` で終了 → ラッパー内 Start-Job の `$LASTEXITCODE = 1`
- ラッパーは `return $LASTEXITCODE` で Receive-Job を介して終了コードを回収
- ラッパー自身も `exit 1` で呼び出し元に返却
- stderr メッセージは `2>&1` で stdout に統合され、呼び出し元（Receive-Job 経由）に確実に届く

## 関連ケース

- [case-11_invalid_pptx_magic.md](case-11_invalid_pptx_magic.md): ZIP マジック不一致
- [case-47_fail_close_stderr_flush.md](case-47_fail_close_stderr_flush.md): fail-close 経路の stderr flush 保証
