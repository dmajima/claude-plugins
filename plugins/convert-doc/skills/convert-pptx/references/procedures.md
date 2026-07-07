# convert-pptx 実行手順

環境構築は `setup.md` を参照すること。
テーマ（デザイン）の選択ルールは `theme-selection.md` を参照すること。

> **実行シェルの注意**: `convert_pptx.py` は python-pptx を使うため、Windows の `PowerShell` ツール経由の
> 直接起動ではハングする既知事象がある。本手順のコマンドは **Bash ツール経由** で実行すること。
> Bash 経由でも timeout 付きで起動したい場合はラッパー
> `${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-pptx/run_via_job.sh`
> （`bash run_via_job.sh <input.md> <output.pptx> --python-exe "<venv python.exe>" -- [オプション...]`）を使用する。

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
  [--max-body-chars 2400] \
  [--theme "<テーマJSONの絶対パス>"]
```

- 出力先が未指定の場合、入力ファイルと同ディレクトリ・同名で `.pptx` 拡張子
- `--aspect` は `16:9` または `4:3`
- `--primary-color` は CSS 色文字列（`#RRGGBB`）。`--theme` の primary より優先される
- `--theme` は省略可（省略時は内蔵デフォルトデザイン）。テーマ JSON はデフォルトの部分上書き
- 不正なテーマ（未知キー・不正色・JSON 構文エラー）は exit 1 でエラーメッセージを出力する

## デフォルトテーマの確認

内蔵デフォルトデザインの全パラメータは以下で JSON として取得できる（新テーマ作成の起点。作成自体は `add-design-pptx` スキルが担当）。

```bash
"$SESSION_DIR/workspace/.venv/Scripts/python" \
  "${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-pptx/convert_pptx.py" \
  --dump-default-theme
```

## スライド分割規則

| Markdown | 出力スライド |
|---------|-------------|
| 最初の `# タイトル` | タイトルスライド（1枚目） |
| H1 が 1 つもない | タイトルスライドを生成しない（本文スライドのみ） |
| 各 `## セクション` | 新規スライドの先頭 |
| `### / #### / ...` | 同一スライド内の小見出し（太字・色付き） |
| H2 が 1 つもない | 全文を 1 枚の「本文スライド」に配置（タイトルなし） |

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
| 表 | `shapes.add_table` ネイティブ表 |
| mermaid | `shapes.add_picture` PNG 画像 |
| ローカル画像 | `shapes.add_picture` |
| HTTP 画像 | `requests` で取得 → `shapes.add_picture` |

## トラブルシューティング

| 症状 | 対応 |
|------|------|
| `Module not found: pptx` | `pip install python-pptx` が正しく venv 内で行われているか確認 |
| mermaid 図が描画されない | mermaid.ink にアクセスできるか確認。失敗時はテキストでコードブロック表示に fallback する |
| スライドからコンテンツがはみ出す | `--max-body-chars` を小さくして自動分割の閾値を下げる |
| 日本語が □ で表示される | 既定フォント（`Yu Gothic UI`）がある環境で閲覧する、またはテーマ JSON の `fonts.body` / `fonts.heading` を環境フォントに変更（`add-design-pptx` スキルで作成） |
