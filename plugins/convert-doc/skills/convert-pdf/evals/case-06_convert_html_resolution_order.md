# Case 06: convert-html スクリプトの解決順序

## 入力

- 入力 MD: 任意
- 以下のシナリオを順に検証:

  | シナリオ | `$CONVERT_HTML_SCRIPT` | `$CLAUDE_PLUGIN_ROOT` | 兄弟ディレクトリ |
  |---------|----------------------|---------------------|----------------|
  | A | 設定済み・ファイル存在 | (任意) | (任意) |
  | B | 未設定 | 設定済み・convert.py 存在 | (任意) |
  | C | 未設定 | 未設定 | 同一プラグイン構造で convert.py 存在 |
  | D | 未設定 | 未設定 | 兄弟も不在 |

## 期待動作

| シナリオ | 解決結果 |
|---------|---------|
| A | `$CONVERT_HTML_SCRIPT` のパスを使用 |
| B | `$CLAUDE_PLUGIN_ROOT/skills/convert-html/scripts/convert/convert.py` を使用 |
| C | `Path(__file__).parent.parent.parent.parent / "convert-html" / ...` を使用（同一プラグイン内兄弟スキル） |
| D | stderr に "convert-html script not found via ..." を出力し `sys.exit(1)` |

## 期待出力

- A/B/C: 正常に PDF が生成される
- D: 終了コード 1、PDF 未生成

## 分岐の根拠

`scripts/convert/convert_pdf.py:locate_convert_html_script()`:
```python
explicit = os.environ.get("CONVERT_HTML_SCRIPT")
if explicit and Path(explicit).exists():
    return Path(explicit)
plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT")
if plugin_root:
    candidate = Path(plugin_root) / "skills" / "convert-html" / ...
    if candidate.exists():
        return candidate
# fallback: sibling
sibling = ...
if sibling.exists():
    return sibling
sys.exit(1)
```

## 関連ケース

なし（環境変数解決ロジック検証）
