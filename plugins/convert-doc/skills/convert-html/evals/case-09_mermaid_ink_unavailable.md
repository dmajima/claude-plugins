# Case 09: mermaid.ink 不通 → エラーブロック出力

## 入力

- 入力 MD: mermaid コードブロックを含む

  ````markdown
  # タイトル
  ```mermaid
  flowchart TD
      A --> B
  ```
  ````

- ネットワーク状態: `mermaid.ink` への HTTPS 接続が失敗（ネットワーク無効・DNS 解決失敗・タイムアウト等）

## 期待動作

1. `fetch_mermaid_svg` が **3 回リトライ**（各 2 秒間隔）
2. すべて失敗した場合、以下のエラー HTML を返す:

   ```html
   <div class="mermaid-error">Mermaid変換エラー (3回試行): <エラー内容(html.escape済)>
   <br><pre><diagram_code(html.escape済)></pre></div>
   ```

3. `<` `>` `&` 等を含む diagram code が HTML にそのまま埋め込まれず、エスケープ済みで表示されることを確認
4. mermaid.ink からの予期しない Content-Type レスポンスもエラーとして扱う（`image/svg+xml` 以外は拒否）

## 期待出力

- 出力 HTML は生成される（処理は中断しない）
- mermaid 部分が `<div class="mermaid-error">` 要素に置換されている
- diagram code 内の `<`, `>`, `&` が `&lt;`, `&gt;`, `&amp;` にエスケープされている

## 分岐の根拠

`scripts/convert/convert.py:fetch_mermaid_svg()`:
- リトライ: `for attempt in range(retries):` （retries=3）
- Content-Type 検証: `if "image/svg+xml" not in ctype and "text/xml" not in ctype: raise ValueError(...)`
- フォールバック: `f'<div class="mermaid-error">...{html_lib.escape(diagram_code)}</pre></div>'`

## 関連ケース

なし（エラー系・セキュリティ）
