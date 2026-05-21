# Case 47: fail-close 経路の stderr が `Start-Process` リダイレクトでも欠落しない（flush 強制）

## 入力

- 入力 PPTX: **存在しないパス**（例: `nonexistent.pptx`）
- 出力 MD: `<セッション>/output.md`
- 起動方法: PowerShell の `Start-Process -RedirectStandardError <file>` でファイルにリダイレクト
- 環境: 修正版 `convert_from_pptx.py`（`print(..., flush=True)` と `sys.stderr.flush()` を全 fail-close 経路に付与済み）

## 期待動作

1. `main()` 内 `if not input_path.exists():` 分岐で `print(f"Error: Input file not found: ...", file=sys.stderr, flush=True)` を実行
2. 直後に `sys.stderr.flush()` を呼び、Windows + Python の stdio バッファが解放される前にファイルへ書き出す
3. `return 1` でプロセス終了（exit code 1）
4. リダイレクト先ファイルに **エラーメッセージが残る**（0 byte で消失しない）

## 期待出力

- 標準出力リダイレクト先: 空
- 標準エラーリダイレクト先（**0 byte ではないこと**）:
  ```
  Error: Input file not found: nonexistent.pptx
  ```
- 終了コード: 1

## 分岐の根拠

`convert_from_pptx.py` の全 fail-close 経路に `flush=True` と明示 flush を付与済み:

```python
if not input_path.exists():
    print(f"Error: Input file not found: {input_path}", file=sys.stderr, flush=True)
    sys.stderr.flush()
    return 1
...
except FileNotFoundError as exc:
    print(f"Error: {exc}", file=sys.stderr, flush=True)
    sys.stderr.flush()
    return 1
except ValueError as exc:
    print(f"Error: {exc}", file=sys.stderr, flush=True)
    sys.stderr.flush()
    return 1
except Exception as exc:
    print(f"Error: unexpected failure: {exc}", file=sys.stderr, flush=True)
    sys.stderr.flush()
    return 2
```

import 失敗時（`pptx` / `lxml` が無い場合）の経路も同様に flush 強制を適用済み。

## 経緯（回帰防止のメモ）

旧版では `print(..., file=sys.stderr)` のあと flush せずに `sys.exit(N)` していたため、
Windows + Python + PowerShell `Start-Process -RedirectStandardError` の組み合わせで
**エラーメッセージがファイルに到達しない**事象が観測された。
親プロセスは exit を検知できず `WaitForExit` でブロックし続け、結果として
「ハング」として観測されていた。

`Start-Job` + `Receive-Job`（テキストパイプ）経由では PowerShell がストリームを
能動的に読むためバッファが解放されるが、`Start-Process -RedirectStandardError` は
**ファイルハンドルがプロセス終了まで stdio バッファを保持**する挙動になりやすく、
明示 flush がなければエラーメッセージが消失する。

本ケースは、リダイレクト経由でも fail-close 時にエラーメッセージが必ず観測できる
ことを保証する。

## 関連ケース

- [case-09_input_not_found.md](case-09_input_not_found.md): 入力ファイル未存在時の挙動
- [case-44_xml_hardening_without_defusedxml.md](case-44_xml_hardening_without_defusedxml.md): defusedxml 撤去後の保護維持
