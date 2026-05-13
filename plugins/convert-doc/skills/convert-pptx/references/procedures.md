# convert-pptx 実行手順

環境構築は `setup.md` を参照すること。

## 変換スクリプト実行

```bash
"$SESSION_DIR/workspace/.venv/Scripts/python" \
  "${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-pptx/convert_pptx.py" \
  "<入力MDファイルパス>" \
  "<出力PPTXファイルパス>" \
  [--title "主題"] \
  [--subtitle "副題"] \
  [--aspect 16:9] \
  [--primary-color "#003879"] \
  [--max-body-chars 2400]
```

- 出力先が未指定の場合、入力ファイルと同ディレクトリ・同名で `.pptx` 拡張子
- `--aspect` は `16:9` または `4:3`
- `--primary-color` は CSS 色文字列（`#RRGGBB`）

## スライド分割規則

| Markdown | 出力スライド |
|---------|-------------|
| 最初の `# タイトル` | タイトルスライド（1枚目） |
| 各 `## セクション` | 新規スライドの先頭 |
| `### / #### / ...` | 同一スライド内の小見出し（太字・色付き） |

## convert_pptx.py の変換処理フロー

1. **入力検証** — 入力 MD ファイルの存在確認
2. **Markdown パース** — 行ベースでブロック要素（見出し・段落・箇条書き・コードフェンス・表・mermaid コードフェンス・画像）に分解
3. **スライド分割** — H2 の出現位置でスライドを区切る
4. **スライド構築** — `python-pptx` で各スライドにタイトル帯とコンテンツ要素を配置
5. **mermaid 取得** — mermaid コードブロックを `mermaid.ink/img` で PNG 化してスライドに埋め込み
6. **画像埋め込み** — ローカル画像は直接、HTTP 画像は `requests` で取得して埋め込み
7. **PPTX 保存**

## ブロック要素のレンダリング

| 要素 | PPTX 表現 |
|------|---------|
| 段落 | テキストフレーム（Body フォント 16pt） |
| 箇条書き | 段落レベル付きテキストフレーム |
| 見出し（H3+） | 太字・プライマリ色のテキストフレーム |
| コードブロック | モノスペースフォント（Consolas/Menlo）のテキストフレーム |
| 表 | `shapes.add_table()` ネイティブ表 |
| mermaid | `shapes.add_picture()` PNG 画像 |
| ローカル画像 | `shapes.add_picture()` |
| HTTP 画像 | `requests` で取得 → `shapes.add_picture()` |

## トラブルシューティング

| 症状 | 対応 |
|------|------|
| `Module not found: pptx` | `pip install python-pptx` が正しく venv 内で行われているか確認 |
| mermaid 図が描画されない | mermaid.ink にアクセスできるか確認。失敗時はテキストでコードブロック表示に fallback する |
| スライドからコンテンツがはみ出す | `--max-body-chars` を小さくして自動分割の閾値を下げる |
| 日本語が □ で表示される | 既定フォント（`Yu Gothic UI`）がある環境で閲覧する、またはスクリプト冒頭の `BODY_FONT` を環境フォントに変更 |
