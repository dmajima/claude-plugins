# 構造化 JSON スキーマと Phase 2 解釈ガイド

`convert_from_pptx.py --structured-json` で出力される JSON のスキーマと、それを Claude が Markdown 化する際のガイドライン。

## 1. JSON スキーマ概要

```jsonc
{
  "metadata": {
    "input_path": "...",
    "slide_count": 18,
    "slide_width_emu": 13439775,
    "slide_height_emu": 7559675,
    "images_dir": "...",
    "template_decoration_texts": [
      "© W2 Co.,Ltd.",   // マスタ/レイアウト由来のテキスト集合
      "Core Colors",
      ...
    ],
    "schema_version": "1.0"
  },
  "slides": [
    {
      "slide_no": 1,
      "layout_name": "CoverC",
      "is_section_cover_layout": true,
      "shapes": [
        {
          "shape_id": 4,
          "name": "Title 3",
          "kind": "TEXT_FRAME",  // PICTURE / TABLE / CHART / CONNECTOR / SMARTART / OTHER
          "auto_shape_type": "RECTANGLE",
          "placeholder": {"idx": 0, "type": "CENTER_TITLE (3)"},
          "group_path": [],  // グループ階層を上位から順に [{shape_id, name}, ...]
          "geometry": {
            "top_emu": 2453852,
            "left_emu": 6358690,
            "width_emu": 7081085,
            "height_emu": 1649186,
            "top_ratio": 0.32,   // スライド高さに対する比率（位置の正規化）
            "left_ratio": 0.47,
            "width_ratio": 0.53,
            "height_ratio": 0.22
          },
          "text": "全文テキスト",
          "paragraphs": [
            {
              "level": 0,
              "runs": [
                {"text": "...", "font_size_pt": 28.0, "bold": false, "color": "FFFFFF"}
              ]
            }
          ],
          "font_size_max_pt": 28.0,
          "font_color": "FFFFFF",
          "is_grayish_color": false,
          "table": null,
          "image": null
        }
      ],
      "connectors": [
        {
          "begin_shape_id": 8,
          "end_shape_id": 7,
          "connector_shape_id": 9
        }
      ],
      "notes": "スピーカーノート文字列"
    }
  ]
}
```

## 2. Phase 2 解釈ガイドライン（Claude 向け）

JSON を読んで Markdown を生成する際の判断基準。

### 2.1 タイトル推定

スライドごとに「タイトル shape」を 1 つ選び `## <タイトル>` とする（1 枚目のみ `# `）。優先順位:

1. `placeholder.type` が `CENTER_TITLE` または `TITLE`（`SUBTITLE` は除外）
2. `geometry.top_ratio <= 0.2` かつ `geometry.height_ratio <= 0.12` の短文（80 文字以下）
3. スライド内 `font_size_max_pt` 最大の shape（章扉スライドの中央タイトル等）
4. いずれもない場合: `## スライド<N>` をフォールバック

### 2.2 装飾要素の除外

以下のいずれかに該当する shape は **本文として出力しない**:

- `placeholder.type` が `FOOTER (15)`, `SLIDE_NUMBER (13)`, `DATE (16)` のいずれか
- `text` が `metadata.template_decoration_texts` に完全一致
- 短文 (`text` 30 字以下) かつ `is_grayish_color` が true
- 短文 (`text` 25 字以下) かつ `geometry.top_ratio > 0.75 && left_ratio > 0.55`（右下隅）
- 同一スライド内で **3 回以上** 出現する同一短文（凡例ラベル）
- 章扉スライド (`is_section_cover_layout`) かつ純数字 1〜3 桁テキスト（章番号装飾）
- `font_size_max_pt` がスライド内中央値の 70% 未満 かつ 30 字以下

### 2.3 フロー図の Mermaid 化

スライドに `connectors` が **2 件以上** 存在する場合、Mermaid `flowchart` として再構成:

1. `connectors[].begin_shape_id` / `end_shape_id` に登場する shape_id 群を「ノード集合」とする
2. 各ノードのラベルは対応する shape の `text`（改行は `<br/>`、`<`/`>` は HTML エスケープ）
3. ノード形状は `auto_shape_type` から推定:
   - `OVAL` / `ELLIPSE` / `FLOWCHART_TERMINATOR` → `(("text"))`
   - `DIAMOND` / `FLOWCHART_DECISION` → `{"text"}`
   - `PARALLELOGRAM` / `FLOWCHART_DATA` → `[/"text"/]`
   - その他 → `["text"]`
4. レイアウト方向は shape 群の `geometry` から判定:
   - 横方向の広がりが縦より大きい → `flowchart LR`
   - 縦方向の広がりが大きい → `flowchart TD`
5. Mermaid に含めたノードは本文出力から除外（重複防止）

### 2.4 テーブル

`kind == "TABLE"` かつ `table` フィールド有りの shape を GFM パイプ表に変換。1 行目をヘッダ、空セルは空のまま、改行は `<br>` に置換。全セル空のテーブルは出力しない。

### 2.5 画像

`kind == "PICTURE"` の shape は `image.markdown_link` をそのまま本文に挿入（既に `![alt](path)` 形式で生成済み）。

### 2.6 視覚順での並べ替え

タイトル以外の出力要素は **基本** `geometry.top_ratio` → `left_ratio` の昇順で並べる。
ただし以下のグルーピングを優先:

- フロー図の Mermaid ブロック → スライド末尾に配置（または該当 shape 群の位置中央値）
- 同じ `top_ratio` (差 0.03 以内) の連続 text 要素 → 1 行に集約（全角スペース区切り）

### 2.7 本文と装飾の見極めヒント

- `placeholder.type` が `BODY (2)` / `OBJECT (7)` / `CONTENT` → 本文
- スライド内最大フォントの 80% 以上のサイズ → 重要な見出し/メッセージ（`**...**` で強調）
- 段落の `bold` 多用 + 短文 → 見出し候補

## 3. フォールバック動作

LLM 呼び出しが行えない場面では、JSON を生成せず Python 単独で Markdown を生成する従来モードを利用する:

```powershell
& "$SESSION_DIR/workspace/.venv/Scripts/python.exe" `
  "${env:CLAUDE_PLUGIN_ROOT}/references/scripts/convert-from-pptx/convert_from_pptx.py" `
  "<input.pptx>" "<output.md>"
```

この場合、装飾フィルタは Python 側のヒューリスティック（フォントサイズ統計・色判定・位置統計）で実行される。`--structured-json` モードとの差分は「意味解釈の精度」のみであり、出力フォーマット自体は同じ Markdown となる。

## 4. JSON サイズの目安

- 1 スライドあたり 5〜30 shape として、JSON サイズはおよそ `slide_count × 15 KB` 程度
- 例: 18 スライドの PPTX で 300 KB 前後
- Claude のコンテキストウィンドウに十分収まるサイズ
