# Case 11: 画像 src が `../` 等で base_dir 外を指す → 元 src を維持

## 入力

- 入力 MD（`./input.md` に配置）:

  ```markdown
  # タイトル
  ![secret](../../etc/passwd)
  ```

  - 攻撃者が悪意ある相対パスで上位ディレクトリのファイルを読み取らせようとするケース

## 期待動作

1. `convert.py:embed_image()` が以下の判定を行う:
   - `src` が `data:` `http://` `https://` で始まる → そのまま返す
   - 解決後パス（`base_dir / src`）が `base_dir.resolve()` 配下でない → **元の src をそのまま返し、埋め込まない**
2. 出力 HTML には `<img src="../../etc/passwd">` のような元の `src` が残る（base64 化されない）
3. ファイル内容は HTML に埋め込まれず、機密情報が漏洩しない

## 期待出力

- 出力 HTML には `<img src="../../etc/passwd">` 相当の元 src が記載される
- 当該ファイルの内容は base64 化されない
- `data:` URI は出力されない

## 分岐の根拠

`scripts/convert/convert.py:embed_image()`:
```python
candidate = base_dir / src
if candidate.exists() and _is_within(base_dir, candidate):
    img_path = candidate
else:
    return src   # 範囲外は埋め込まずに元 src を返す
```

## 関連ケース

なし（セキュリティ・パストラバーサル対策）
