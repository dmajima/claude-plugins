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
| `composition` | object | 構図（表紙・本文見出し部のレイアウト構造）。省略時は既定構図（後述） |

## colors（配色）

| キー | デフォルト | 効く場所 |
|-----|-----------|---------|
| `primary` | `#003879` | タイトル帯背景 / タイトルスライド左バー / タイトルスライド見出し文字 / H3+ 見出し文字 / 表ヘッダ背景 |
| `accent` | `#1D6FD1` | `composition` の色トークンとして参照可能（既定デザイン自体では未使用） |
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
| `title_band_height` | 0.9 | タイトル帯の高さ（**既定構図でのみ使用**。`composition.content_header` を上書きしたテーマでは参照されない） |
| `content_padding` | 0.5 | コンテンツ左右パディング |
| `mermaid_max_width` | 11.5 | mermaid 画像の最大幅 |
| `mermaid_max_height` | 5.5 | mermaid 画像の最大高さ |
| `image_max_width` | 11.5 | 画像の最大幅 |
| `image_max_height` | 5.5 | 画像の最大高さ |

- スライド分割の縦積算（1 スライドに収める本文量）は **コンテンツ開始位置 `content_top` 基準**
  （`スライド高 − content_top − (content_padding + 0.4)`）。既定構図の `content_top` は
  `title_band_height + 0.2` に追従するため、`title_band_height` / `content_padding` を
  大きく変えるとスライド枚数が変わる。カスタム構図では `composition.content_header.content_top` が
  そのまま基準になる
- `composition.content_header` を上書きしたテーマに `layout_in.title_band_height` を併記すると、
  「参照されない」旨の警告が stderr に出る（エラーにはならない。`cover` のみの上書きでは
  既定の見出し部が `title_band_height` を参照し続けるため警告されない）
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

## composition（構図）

表紙（`cover`）と本文スライド見出し部（`content_header`）のレイアウト構造を宣言的に定義する。
矩形シェイプ群 + テキスト配置 + コンテンツ開始位置を自由に記述でき、
**スクリプト改修なしで新しいレイアウトをテーマ追加だけで作成できる**。

- **各部位は丸ごと置換**: `cover` / `content_header` は部位単位で既定構図を完全に置き換える
  （部位内の deep merge はしない）。`cover` だけ・`content_header` だけの片側上書きは可
- `composition` を書く場合、`cover` / `content_header` の **少なくとも一方が必須**（空オブジェクトはエラー）
- **フォント名・フォントサイズは composition に持たない**（composition = 幾何、既存セクション = 表現）。
  従来どおり `fonts` / `font_sizes_pt` を参照する:
  cover title → `title_slide_title`、cover subtitle → `title_slide_subtitle`、
  content_header title → `title_band`（フォントは title 系 = heading、subtitle = body）
- 未知キーは他セクション同様エラー（タイポ検出）

### shapes[]（装飾矩形。塗りのみ・枠線なし）

配列順に描画される（後勝ち重なり）。描画後、title / subtitle テキストが最前面に載る。

| キー | 型 | 必須 | 内容 |
|-----|-----|------|------|
| `x`, `y` | number（inch） | 必須 | 左上座標。**0 以上**（`x=0` / `y=0` は下端帯・左バー等で正当）。スライド高は 16:9 / 4:3 とも 7.5in のため `y` は絶対値で可搬 |
| `w` | number \| `"full"` \| `"sym"` | 必須 | `full` = スライド全幅、`sym` = 全幅 − x×2（左右対称マージン）。スライド幅はアスペクト比で変わるため、右端まで届く幅は絶対値でなくトークンで書く |
| `h` | number \| `"full"` | 必須 | `full` = スライド全高 |
| `color` | 色トークン名 \| hex | 必須 | 色トークン = `colors` セクションのキー名（`primary` / `accent` / `hr` 等）。テーマ配色（`--primary-color` 上書き含む）に自動追従。hex 直接指定も可 |

- `"shapes": []` は省略と等価（装飾なし）
- `"sym"` は `x` が大きいと解決結果が負になり得る（例: 16:9 で `x=8.0` → 13.333 − 16.0 < 0）。
  検証ツールはスライド幅を知らないため検出できず、**描画時に幅・高さが 0 以下となった要素は
  スキップされ stderr に警告が出る**（安全網）

### title / subtitle（テキスト配置。subtitle は cover のみ）

| キー | 型 | 必須 | 既定 | 内容 |
|-----|-----|------|------|------|
| `x`, `y` | number（inch, 0 以上） | 必須 | — | 配置ボックス左上 |
| `w` | number \| `"sym"` | 必須 | — | ボックス幅 |
| `h` | number（正） | 必須 | — | ボックス高さ |
| `color` | 色トークン名 \| hex | 必須 | — | 文字色 |
| `bold` | boolean | 任意 | title: `true` / subtitle: `false` | 太字 |
| `align` | `"left"` \| `"center"` \| `"right"` | 任意 | `left` | 水平揃え |
| `anchor` | `"top"` \| `"middle"` | 任意 | `top` | ボックス内の垂直位置 |
| `margin` | number（inch, 0 以上） | 任意 | 0.1（pptx テキストボックス既定） | text_frame の左右内部マージン。実効テキスト開始 X = `x + margin` |

### content_header 固有

| キー | 型 | 必須 | 内容 |
|-----|-----|------|------|
| `content_top` | number（inch, 正） | 必須 | 本文ブロックの開始 Y。スライド分割の縦積算もこの値基準（`layout_in` の説明参照） |

- `cover` を上書きする場合 `title` / `subtitle` は必須、`content_header` を上書きする場合
  `title` / `content_top` は必須（`shapes` は任意）
- スライドタイトルが無い物理スライド（H2 なしの継続ページ等）は従来どおり見出し部を描画せず、
  コンテンツ開始 Y も従来ロジック（0.3in）を維持する
- `content_top` が過大な場合は既存の `Warning: N block(s) did not fit ...` 警告が安全網として機能する

### 設計ガイド

- **shapes・テキストは `content_top` より上に収める**こと（見出し部と本文の重なり防止）。
  下端装飾（表紙の下端帯等）は例外的に `content_top` と無関係な `cover` でのみ推奨
- 既定構図リファレンス（次節）を種にして座標を調整し、検証（`validate_theme.py`）→
  サンプル変換 → 生成 PPTX の座標確認、の順で仕上げる
- shapes と `content_top` の位置整合はテーマ作成者の責任（スクリプトは重なりを検出しない）

### 既定構図リファレンス

`composition` 省略時に内部生成される構図。**SSOT はコード側**
（`convert_pptx.py` の `build_default_composition()`）であり、本節は参考リファレンス。
同期は `check_default_composition.py`（`references/scripts/add-design-pptx/`）で機械照合される。

以下は既定テーマ値（`title_band_height` 0.9）・16:9（幅 13.333in）で具現化した値。
`cover.title` / `cover.subtitle` の `w` はスライド全幅 − 1.5、`content_header` の帯高さと
`content_top`（= 帯高さ + 0.2）は `layout_in.title_band_height` に**動的追従**する。

<!-- default-composition-16x9:begin -->
```json
{
  "cover": {
    "shapes": [{"x": 0, "y": 0, "w": 0.4, "h": "full", "color": "primary"}],
    "title":    {"x": 1.0, "y": 2.3, "w": 11.833, "h": 2.0, "color": "primary", "bold": true, "align": "left", "anchor": "top", "margin": 0.1},
    "subtitle": {"x": 1.0, "y": 4.4, "w": 11.833, "h": 1.5, "color": "text", "bold": false, "align": "left", "anchor": "top", "margin": 0.1}
  },
  "content_header": {
    "shapes": [{"x": 0, "y": 0, "w": "full", "h": 0.9, "color": "primary"}],
    "title": {"x": 0, "y": 0, "w": "full", "h": 0.9, "color": "on_primary", "bold": true, "align": "left", "anchor": "middle", "margin": 0.35},
    "content_top": 1.1
  }
}
```
<!-- default-composition-16x9:end -->

※ `content_header.title` の `w: "full"` は既定構図の内部表現。テーマ JSON から指定できる
テキスト幅は number または `"sym"` のみ（`x=0` + `margin=0.35` により、旧実装の帯内テキストと
同じ実効開始位置 0.35in を再現している）。

### `--dump-default-theme` が composition を含めない理由

既定構図は `title_band_height` 等のテーマ値に動的追従する。静的 JSON として dump すると、
「dump した composition」と「`layout_in` の変更」が不整合を起こし、併用警告の誤発火も招く。
このため `--dump-default-theme` の出力に `composition` は含めず、既定構図の参照先は
本ドキュメント（と SSOT のコード）に一本化する。カスタム構図を持つテーマを round-trip した
場合のみ `composition` がシリアライズされる。

### 記述例（executive 風の構図上書き）

表紙: 左バーなし・ゴールドルール + 下端ライン/帯。本文: 塗り帯なしのキーメッセージ +
全幅ヘアライン + アクセント短線。

```json
{
  "font_sizes_pt": {
    "title_band": 20,
    "title_slide_title": 38,
    "title_slide_subtitle": 16
  },
  "composition": {
    "cover": {
      "shapes": [
        {"x": 1.0, "y": 2.15, "w": 1.3, "h": 0.045, "color": "accent"},
        {"x": 0, "y": 7.04, "w": "full", "h": 0.04, "color": "accent"},
        {"x": 0, "y": 7.08, "w": "full", "h": 0.42, "color": "primary"}
      ],
      "title":    {"x": 1.0, "y": 2.45, "w": "sym", "h": 1.9, "color": "primary", "bold": true},
      "subtitle": {"x": 1.0, "y": 4.5,  "w": "sym", "h": 1.2, "color": "#5F6B7A"}
    },
    "content_header": {
      "shapes": [
        {"x": 0.5, "y": 1.09,  "w": "sym", "h": 0.012, "color": "hr"},
        {"x": 0.5, "y": 1.075, "w": 1.2,   "h": 0.035, "color": "accent"}
      ],
      "title": {"x": 0.5, "y": 0.2, "w": "sym", "h": 0.83, "color": "primary", "bold": true, "anchor": "middle"},
      "content_top": 1.35
    }
  }
}
```

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
