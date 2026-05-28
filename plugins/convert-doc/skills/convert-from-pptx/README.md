# convert-from-pptx スキル

PowerPoint (PPTX) を Claude が読み込める Markdown に変換するスキル。`convert-doc` プラグインに同梱されている。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は `SKILL.md` および `references/` 配下を参照してください。

## 導入手順

本スキルは `convert-doc` プラグインに同梱されています。プラグインのインストール方法はリポジトリルートの [`README.md`](../../../../README.md) を参照してください。

```text
/plugin install convert-doc@dmajima-claude-plugins
```

依存パッケージ（python-pptx / Pillow / lxml）は初回実行時に `references/scripts/setup/setup_venv.sh`（Windows 11 推奨）または `setup_venv.sh`（POSIX 互換）が自動で venv を構築してインストールします。本スキルは外部ネットワークアクセスを行いません（オフライン環境でも動作）。

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

### 最小例

```text
ユーザ:
> このPPTXをMarkdownに変換して

Claude（要約）:
> 入力PPTXを構造化JSONに抽出し、文脈解釈してMarkdownを生成しました。
> 出力: report.md、画像: report_images/
```

### 自然言語

- 「この PPTX を Markdown に変換して」
- 「スライドを読める形にして転記して」
- 「設計書 PPTX を MD で出力」

### スクリプト直接実行

```bash
& "$SESSION_DIR/workspace/.venv/Scripts/python.exe" \
  "$CLAUDE_PLUGIN_ROOT/references/scripts/convert-from-pptx/convert_from_pptx.py" \
  "<入力PPTX>" "<出力MD>" \
  [--images-dir DIR] [--no-mermaid] [--include-notes]
```

<details><summary>PowerShell フォールバック</summary>

```powershell
& "$SESSION_DIR/workspace/.venv/Scripts/python.exe" `
  "${env:CLAUDE_PLUGIN_ROOT}/references/scripts/convert-from-pptx/convert_from_pptx.py" `
  "<入力PPTX>" "<出力MD>" `
  [--images-dir DIR] [--no-mermaid] [--include-notes]
```

</details>

## 技術スタック / 動作要件

| 項目 | 内容 |
|------|------|
| Python | 3.9 以上 |
| 主要依存 | `python-pptx` (PPTX パース), `lxml` (SmartArt XML 解析・XXE 対策), `Pillow` (画像メタ取得) |
| 依存リスト | `${env:CLAUDE_PLUGIN_ROOT}/references/scripts/setup/requirements.txt`（バージョン下限固定） |
| シェル | PowerShell 7+（Windows 11 主動作環境）、`.sh` は POSIX 環境向けの互換版 |
| 外部通信 | なし（オフライン動作） |
| 出力エンコーディング | UTF-8 / LF / BOM なし |

## ファイル構成

```
plugins/convert-doc/
├── references/scripts/
│   ├── setup/                       # 統合 venv 構築（プラグイン共通、ADR-024）
│   │   ├── requirements.txt         # 全スキル分の依存をマージ（バージョン下限固定）
│   │   ├── setup_venv.sh           # PowerShell 版（推奨・Windows 11）
│   │   ├── teardown_venv.sh
│   │   ├── setup_venv.sh            # POSIX 互換版
│   │   └── teardown_venv.sh
│   └── convert-from-pptx/           # 本スキル業務スクリプト（ADR-025）
│       ├── convert_from_pptx.py     # PPTX → Markdown / JSON 変換
│       └── verify_md.py             # Phase 3 カバレッジ検証
└── skills/convert-from-pptx/
    ├── SKILL.md
    ├── README.md
    ├── references/
    │   ├── design.md                # 設計方針・対応規則
    │   ├── procedures.md            # 標準実行手順
    │   ├── setup.md                 # 環境構築
    │   ├── options.md               # CLI オプション一覧
    │   ├── json-schema.md           # 構造化 JSON スキーマ
    │   ├── validation.md            # Phase 3 検証ガイド
    │   └── large-pptx-workflow.md   # 大規模 PPTX フロー
    └── evals/
        ├── README.md
        ├── case-01_normal_with_title.md 〜 case-22_image_extension_allowlist.md（基本ケース 22 件）
        ├── case-23a_structured_json_normal.md / case-23b_json_only_alone.md（Phase 1 JSON モード）
        ├── case-24a_per_slide_json.md / case-24b_compact_view.md（中〜大規模対応）
        ├── case-25a/25b/25c（Phase 3 検証）
        ├── case-26_interactive_mode.md / case-27_fallback_mode.md
        ├── case-28_lr_flowchart.md / case-29_content_types_missing.md / case-30_title_estimation_fallback.md
        └── case-31〜case-40（境界値・--workspace-root traversal・JSON+MD 同時出力 等 10 件）
```

## カスタマイズ

- Mermaid 変換のしきい値（コネクタ最小本数、対象シェイプ種別など）は `${env:CLAUDE_PLUGIN_ROOT}/references/scripts/convert-from-pptx/convert_from_pptx.py` 冒頭の定数を編集する
- モノスペース判定対象フォント名は `MONOSPACE_FONTS` 定数で管理する
- 画像の最大サイズや出力ファイル名規則は `--max-image-size` および `_image_filename()` を編集する
- スピーカーノートのプレフィックス（`> [!NOTE]`）は `_format_notes()` を編集する
- 抽出を許可する画像拡張子（既定: png/jpg/jpeg/gif/bmp/tiff/webp/emf/wmf）は `ALLOWED_IMAGE_EXTS` 定数で管理する。`emf` / `wmf` は Markdown レンダラ側で表示できない場合があるが、Office 文書由来の素材として原本保持の意義があるため allowlist に含めている
