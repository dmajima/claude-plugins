# Case 05: Playwright/Chromium 未インストール

## 入力

- 入力 MD: 任意
- 環境: Playwright が venv にインストールされていない、または Chromium バイナリが取得されていない

## 期待動作

### Playwright パッケージ未インストール時

1. `render_pdf()` 内の `from playwright.sync_api import sync_playwright` で `ImportError`
2. Python ランタイムが `ImportError` のスタックトレースを stderr に出力して終了

### Chromium バイナリ未取得時

1. `p.chromium.launch()` で `playwright._impl._errors.Error: Executable doesn't exist at ...` 系のエラー
2. ユーザーに `playwright install chromium` の実行を促すメッセージ

## 期待出力

- 標準エラー: `ImportError` または Playwright のエラー
- 終了コード: 非ゼロ
- 出力 PDF: 生成されない

## 分岐の根拠

`references/scripts/convert-pdf/convert_pdf.py:render_pdf()`:
```python
from playwright.sync_api import sync_playwright   # 関数内 import
```

→ Playwright 不在時は関数呼び出し時に ImportError を発生させる仕様

## 関連ケース

なし（環境エラー系）
