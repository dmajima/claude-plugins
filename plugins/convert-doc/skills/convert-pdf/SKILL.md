---
name: convert-pdf
description: >
  Markdown ファイルを Wiki スタイルの PDF ファイルに変換するスキル。
  内部で convert-html スキルを使って HTML を生成し、Playwright (Chromium) で PDF 化する。
  mermaid 図・シンタックスハイライト・表・画像もすべて HTML 版と同一デザインで再現される。
  「MD を PDF に変換」「資料を PDF で出力」「設計書を PDF 化して」「convert-pdf」などの依頼に必ず使用すること。
---

# convert-pdf スキル

Markdown ファイルを Wiki デザインの PDF に変換する。

## 出力の特徴

- `convert-html` の出力する自己完結型 HTML を Chromium で PDF 化するため **HTML 版と同一デザイン**
- mermaid 図・シンタックスハイライト・表・画像をそのまま PDF に焼き込み
- A4 縦・背景色印刷あり（`print_background: true`）がデフォルト
- ページ番号・余白はオプションで上書き可能

## 実行フロー

1. **ワークディレクトリ作成**（`.claude/.local/work/yyyyMMdd_nn_convert_pdf/{inputs,workspace}`）
2. **venv 構築**（`workspace/.venv` 配下）→ 依存パッケージをインストール
3. **Chromium インストール**（初回のみ、`playwright install chromium`）
4. **変換スクリプト実行**
5. **出力ファイルをユーザーに報告**（最終 PDF はセッションフォルダ直下）
6. **venv 削除**

詳細な実行手順は `references/procedures.md`、環境構築（venv・依存パッケージ）は `references/setup.md` を参照。

## アセットの場所

- 変換スクリプト: `${CLAUDE_SKILL_DIR}/scripts/convert/convert_pdf.py`
- 依存スキル: 同一プラグイン内の `convert-html`（兄弟スキル）を内部的に呼び出す

## オプション

| オプション | 省略値 | 内容 |
|-----------|-------|------|
| `--title` | MD 内の最初の H1 | ドキュメントタイトル |
| `--format` | `A4` | 用紙サイズ（`A4`, `A3`, `Letter` など） |
| `--landscape` | なし | 横向きに切り替え |
| `--margin` | `20mm` | 全辺の余白（`top right bottom left` 個別指定も可） |
| `--no-background` | なし | 背景色を印刷しない（モノクロ印刷向け） |

## 依存スキル

- `convert-html`（同一プラグイン内）— HTML 生成のために内部で呼び出す
