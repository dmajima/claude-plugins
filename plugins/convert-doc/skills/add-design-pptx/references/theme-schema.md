# PPTX テーマ JSON スキーマ

convert-pptx のテーマ JSON（`convert_pptx.py --theme <path>` で適用）の完全スキーマ。

## 基本ルール

- **部分指定**: すべてのキーは省略可能。省略したキーはデフォルトデザインの値になる
  （省略はキーごと書かないこと。`"colors": null` のような明示的な null はエラーになる）
- **未知キーはエラー**: タイポ検出のため、定義外のキーがあると exit 1 で拒否される
- **色は hex 文字列**: `#RGB` または `#RRGGBB`（先頭の `#` は省略可）
- **数値は正の数**: `font_sizes_pt` / `layout_in` は 0 より大きい有限の数値
- デフォルト値の SSOT は `convert_pptx.py` 内蔵値。`--dump-default-theme` で JSON として取得できる
- `--dump-default-theme` の出力を新テーマの種にする場合、`name` は `"default"`（予約名）の
  まま出力されるため、**必ず新デザイン名に書き換える**（`name` はメタ情報で解決はファイル名基準だが、
  予約名の混入を避ける）

```bash
"$SESSION_DIR/workspace/.venv/Scripts/python" \
  "${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-pptx/convert_pptx.py" \
  --dump-default-theme
```

## トップレベル構造

| キー | 型 | 内容 |
|-----|-----|------|
| `name` | string | テーマ名（メタ情報・処理には使われない） |
| `description` | string | 説明（メタ情報） |
| `colors` | object | 配色（下表） |
| `fonts` | object | フォント名（下表） |
| `font_sizes_pt` | object | フォントサイズ pt（下表） |
| `layout_in` | object | レイアウト寸法 inch（下表） |
| `syntax_palette` | object | コードのシンタックスハイライト配色（下表） |

## colors（配色）

| キー | デフォルト | 効く場所 |
|-----|-----------|---------|
| `primary` | `#003879` | タイトル帯背景 / タイトルスライド左バー / タイトルスライド見出し文字 / H3+ 見出し文字 / 表ヘッダ背景 |
| `accent` | `#1D6FD1` | 予約（現バージョンでは未使用） |
| `text` | `#1F2D3D` | 段落・箇条書き・サブタイトル・表本文の文字色 |
| `on_primary` | `#FFFFFF` | primary 塗りの上の文字色（タイトル帯・表ヘッダ） |
| `code_bg` | `#F5F6F8` | コードブロック背景 |
| `code_text` | `#1F2D3D` | コードブロック基本文字色（トークン色が付かない部分） |
| `code_border` | `#DDE1E8` | コードブロック枠線 |
| `hr` | `#C9D0D8` | 水平線（`---`） |
| `table_row_odd` | `#FFFFFF` | 表の奇数行背景 |
| `table_row_even` | `#F5F6F8` | 表の偶数行背景 |

- `--primary-color` CLI 引数はテーマの `primary` より優先される

## fonts（フォント名）

| キー | デフォルト | 効く場所 |
|-----|-----------|---------|
| `body` | `Yu Gothic UI` | 段落・箇条書き・表・サブタイトル |
| `heading` | `Yu Gothic UI` | タイトル帯・タイトルスライド見出し |
| `code` | `Consolas` | コードブロック |

- 閲覧環境にインストールされているフォント名を指定すること（存在しない場合 PowerPoint が代替フォントで表示する）

## font_sizes_pt（フォントサイズ）

| キー | デフォルト | 効く場所 |
|-----|-----------|---------|
| `title_band` | 24 | 各スライド上部のタイトル帯 |
| `title_slide_title` | 40 | タイトルスライドの主題 |
| `title_slide_subtitle` | 18 | タイトルスライドの副題 |
| `body` | 16 | 段落 |
| `heading_h3` | 22 | H3 見出し（H4 以降は 2pt ずつ減、下限 14pt） |
| `list` | 15 | 箇条書き・番号付きリスト |
| `code` | 11 | コードブロック |
| `table` | 12 | 表のセル |

## layout_in（レイアウト寸法・inch）

| キー | デフォルト | 内容 |
|-----|-----------|------|
| `title_band_height` | 0.9 | タイトル帯の高さ |
| `content_padding` | 0.5 | コンテンツ左右パディング |
| `mermaid_max_width` | 11.5 | mermaid 画像の最大幅 |
| `mermaid_max_height` | 5.5 | mermaid 画像の最大高さ |
| `image_max_width` | 11.5 | 画像の最大幅 |
| `image_max_height` | 5.5 | 画像の最大高さ |

- `title_band_height` / `content_padding` はスライド分割の縦積算にも使われるため、大きく変えるとスライド枚数が変わる
- **過大な値（例: `title_band_height` をスライド高 7.5in に近づける）は本文の縦領域を消し、
  収まらないブロックが描画されない**（その場合スクリプトが stderr に
  `Warning: N block(s) did not fit ...` を出力する）。デフォルトから大きく動かさないこと
- 高さ見積もりは既定フォントサイズ前提の概算のため、`font_sizes_pt` を大幅に上げると
  テキストの重なり・はみ出しが発生し得る。サンプル変換で必ず見た目を確認すること
- 4:3（幅 10in）で使う場合、`mermaid_max_width` / `image_max_width` は 9.0 以下を推奨

## syntax_palette（シンタックスハイライト配色）

| キー | デフォルト | 対象トークン |
|-----|-----------|-------------|
| `keyword` | `#007B83` | 予約語 |
| `builtin` | `#5C3566` | 組み込み名 |
| `func` | `#004EB0` | 関数・クラス・デコレータ名 |
| `tag` | `#007B83` | マークアップタグ名 |
| `attr` | `#AA5500` | 属性名 |
| `string` | `#4E952A` | 文字列リテラル |
| `number` | `#AA5500` | 数値リテラル |
| `operator` | `#333333` | 演算子・区切り記号 |
| `comment` | `#808080` | コメント |
| `error` | `#B72525` | エラートークン |
| `heading` | `#004EB0` | 見出しトークン（Markdown 等） |

- `code_bg` を暗色にする場合は `syntax_palette` 全キーと `code_text` を明色系に揃えること（コントラスト確保）

## 記述例（ダーク系テーマの部分指定）

```json
{
  "name": "dark-console",
  "description": "ダーク基調のエンジニア向けテーマ",
  "colors": {
    "primary": "#0F3460",
    "code_bg": "#16213E",
    "code_text": "#E8E8E8",
    "code_border": "#0F3460"
  },
  "syntax_palette": {
    "keyword": "#4FC3F7",
    "string": "#A5D6A7",
    "comment": "#78909C"
  }
}
```
