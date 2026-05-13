# convert-from-pptx スキル

PowerPoint (PPTX) を Claude が読み込める Markdown に変換するスキル。`convert-doc` プラグインに同梱されている。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は `SKILL.md` および `references/` 配下を参照してください。

## 導入手順

本スキルは `convert-doc` プラグインに同梱されています。プラグインのインストール方法はリポジトリルートの [`README.md`](../../../../README.md) を参照してください。

```text
/plugin install convert-doc@dmajima-claude-plugins
```

依存パッケージ（python-pptx / Pillow / lxml）は初回実行時に `references/scripts/setup/setup_venv.sh` が自動で venv を構築してインストールします。本スキルは外部ネットワークアクセスを行いません（オフライン環境でも動作）。

## 仕組み

1. 入力 PPTX を `python-pptx` で読み込み
2. 各スライドを順に巡回し、placeholder からタイトルを抽出
3. テキストフレームの段落・箇条書きを Markdown に変換（レベル・装飾を保持）
4. 表（`shape.has_table`）を Markdown パイプ表に変換
5. 画像（`MSO_SHAPE_TYPE.PICTURE`）をバイナリ抽出し、出力 MD と同階層の `<basename>_images/` に保存。Markdown では相対パス参照
6. 図形 + コネクタの構造を解析し Mermaid `flowchart` に変換
7. SmartArt は内部の `diagramData` XML を `lxml` で解析し、解析可能な階層を Mermaid 化
8. スピーカーノートは `--include-notes` 指定時のみ `> [!NOTE]` ブロックとして出力
9. Markdown を UTF-8 / LF で書き出し

## 使い方

### 自然言語

- 「この PPTX を Markdown に変換して」
- 「スライドを読める形にして転記して」
- 「設計書 PPTX を MD で出力」

### スクリプト直接実行

```bash
"$SESSION_DIR/workspace/.venv/Scripts/python" \
  "${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-from-pptx/convert_from_pptx.py" \
  "<入力PPTX>" "<出力MD>" \
  [--images-dir DIR] [--no-mermaid] [--include-notes]
```

## ファイル構成

```
plugins/convert-doc/
├── references/scripts/
│   ├── setup/                       # 統合 venv 構築（プラグイン共通、ADR-024）
│   │   ├── requirements.txt         # 全 4 スキル分の依存をマージ
│   │   ├── setup_venv.sh
│   │   └── teardown_venv.sh
│   └── convert-from-pptx/           # 本スキル業務スクリプト（ADR-025）
│       └── convert_from_pptx.py
└── skills/convert-from-pptx/
    ├── SKILL.md
    ├── README.md
    ├── references/
    │   ├── procedures.md
    │   └── setup.md
    └── evals/
        ├── README.md
        ├── case-01_normal_with_title.md
        ├── case-02_no_title_placeholder.md
        ├── case-03_table_conversion.md
        ├── case-04_image_extraction.md
        ├── case-05_flowchart_mermaid.md
        ├── case-06_smartart_mermaid.md
        ├── case-07_speaker_notes.md
        ├── case-08_hidden_slide.md
        ├── case-09_input_not_found.md
        ├── case-10_path_traversal_images_dir.md
        ├── case-11_invalid_pptx_magic.md
        ├── case-12_max_image_size_overflow.md
        ├── case-13_monospace_code_block.md
        ├── case-14_no_mermaid_flag.md
        ├── case-15_empty_pptx.md
        ├── case-16_invalid_content_types.md
        ├── case-17_invalid_extension.md
        ├── case-18_no_first_slide_as_title.md
        ├── case-19_chart_shape.md
        ├── case-20_smartart_fallback.md
        ├── case-21a_zip_bomb_total_size.md
        ├── case-21b_zip_bomb_compression_ratio.md
        └── case-22_image_extension_allowlist.md
```

## カスタマイズ

- Mermaid 変換のしきい値（コネクタ最小本数、対象シェイプ種別など）は `${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-from-pptx/convert_from_pptx.py` 冒頭の定数を編集する
- モノスペース判定対象フォント名は `MONOSPACE_FONTS` 定数で管理する
- 画像の最大サイズや出力ファイル名規則は `--max-image-size` および `_image_filename()` を編集する
- スピーカーノートのプレフィックス（`> [!NOTE]`）は `_format_notes()` を編集する
- 抽出を許可する画像拡張子（既定: png/jpg/jpeg/gif/bmp/tiff/webp/emf/wmf）は `ALLOWED_IMAGE_EXTS` 定数で管理する。`emf` / `wmf` は Markdown レンダラ側で表示できない場合があるが、Office 文書由来の素材として原本保持の意義があるため allowlist に含めている
