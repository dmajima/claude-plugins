# Case 44a: `defusedxml` 未インストール（デフォルト挙動：フェイルクローズ）

## 入力

- 入力 PPTX: 任意の有効な PPTX
- 出力 MD: `<セッション>/output.md`
- 環境: venv に `defusedxml` がインストールされていない、または import に失敗する状態
- 環境変数: `CONVERT_FROM_PPTX_ALLOW_UNHARDENED_XML` 未設定

## 期待動作

1. スクリプト起動時に `import defusedxml.lxml` を試行 → `ImportError` 発生
2. デフォルトは **フェイルクローズ** のため、エラーメッセージを stderr に出力して `sys.exit(2)` で停止
3. python-pptx は import されず、後続処理は一切実行されない
4. 終了コード: 2

## 期待出力

- 標準エラー:
  ```
  Error: defusedxml is required for safe XML handling (CWE-611 / CWE-776). Install with: pip install defusedxml. To bypass at your own risk, set CONVERT_FROM_PPTX_ALLOW_UNHARDENED_XML=1.
  ```
- 終了コード: 2

## 分岐の根拠

`convert_from_pptx.py` および `verify_md.py` の冒頭 import セクション:
```python
import os as _os
_allow_unhardened_xml = _os.environ.get("CONVERT_FROM_PPTX_ALLOW_UNHARDENED_XML", "") == "1"
try:
    import defusedxml.lxml as _defused_lxml
    _defused_lxml.monkey_patch_lxml()
except ImportError:
    _xml_msg = (
        "defusedxml is required for safe XML handling (CWE-611 / CWE-776). ..."
    )
    if _allow_unhardened_xml:
        print(f"Warning: {_xml_msg}", file=sys.stderr)
    else:
        print(f"Error: {_xml_msg}", file=sys.stderr)
        sys.exit(2)
```

XXE / Billion Laughs 攻撃から python-pptx 内部 lxml を守るためのフェイルクローズ設計。
`defusedxml` 未インストール環境では安全側に倒して停止する。

## 関連ケース

- [case-44b_defusedxml_missing_opt_out.md](case-44b_defusedxml_missing_opt_out.md): opt-out 環境変数による警告継続
- [case-21a_zip_bomb_total_size.md](case-21a_zip_bomb_total_size.md): 別の XML/ZIP 防御
