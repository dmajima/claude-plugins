# Case 44b: `defusedxml` 未インストール（opt-out 環境変数で警告継続）

## 入力

- 入力 PPTX: 任意の有効な PPTX
- 出力 MD: `<セッション>/output.md`
- 環境: venv に `defusedxml` がインストールされていない
- 環境変数: `CONVERT_FROM_PPTX_ALLOW_UNHARDENED_XML=1`

## 期待動作

1. スクリプト起動時に `import defusedxml.lxml` を試行 → `ImportError` 発生
2. `CONVERT_FROM_PPTX_ALLOW_UNHARDENED_XML=1` のため、Warning メッセージを stderr に出力して **処理継続**（オプトアウト）
3. python-pptx の lxml はハードニングされていない状態で動作する
4. 通常の変換処理が実行され、Markdown が生成される
5. 終了コード: 0

## 期待出力

- 標準エラー:
  ```
  Warning: defusedxml is required for safe XML handling (CWE-611 / CWE-776). Install with: pip install defusedxml. To bypass at your own risk, set CONVERT_FROM_PPTX_ALLOW_UNHARDENED_XML=1.
  ```
- 標準出力: 通常の変換完了メッセージ（`Wrote: ...`）
- 終了コード: 0

## 注意

このケースは **既知のセキュリティ低下** を伴う運用形態。CI / 共有環境では使用せず、ローカル開発時の暫定回避策に限定すること。XXE / Billion Laughs 攻撃を含む悪意 PPTX を扱う場合は必ず `defusedxml` をインストールする。

## 分岐の根拠

```python
if _allow_unhardened_xml:
    print(f"Warning: {_xml_msg}", file=sys.stderr)
else:
    print(f"Error: {_xml_msg}", file=sys.stderr)
    sys.exit(2)
```

「セキュアデフォルト + 明示的 opt-out」の設計パターン。環境変数を立てる行為自体が「リスクを承知している」シグナルとなる。

## 関連ケース

- [case-44a_defusedxml_missing_default.md](case-44a_defusedxml_missing_default.md): デフォルトのフェイルクローズ
