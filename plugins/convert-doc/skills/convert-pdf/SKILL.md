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

## 責務

- Markdown → PDF への変換（A4 縦・背景色印刷ありが既定）
- `convert-html` スキルを内部で呼び出して中間 HTML を生成
- Playwright (Chromium) による HTML → PDF レンダリング
- 用紙サイズ・余白・向き・背景色印刷の調整

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| 自己完結型 HTML の生成本体 | `convert-html`（本スキルが内部で呼び出す） |
| PPTX への変換 | `convert-pptx`（独立パイプライン） |
| Chromium バイナリの管理 | Playwright が自動管理（`playwright install chromium`） |

## トリガー条件

- 「MD を PDF に変換」「資料を PDF で出力」「設計書を PDF 化して」等の自然言語依頼
- `/convert-pdf` スラッシュコマンド
- 他スキルからの `Skill(skill: "convert-pdf", ...)` 呼び出し

このスキルを起動しないケース:

- HTML / PPTX への変換依頼（`convert-html` / `convert-pptx` へルーティング）

## 前提

- 入力 Markdown ファイルがローカルに存在し読み取り可能
- Python 3.9+ が利用可能
- インターネット接続あり（Playwright Chromium 初回ダウンロード ~120MB、mermaid.ink、Google Fonts）
- 同一プラグイン内に `convert-html` スキルが配備されている

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `/convert-pdf` または自然言語依頼 | 通常 | デフォルトオプション（A4 縦・背景印刷あり）で処理 |
| `--landscape` / `--no-background` / `--format` 等のオプション指定 | カスタム | 指定されたオプションで Playwright `page.pdf()` を呼び出し |

## 実行フロー

1. **ワークディレクトリ作成**（`.claude/.local/work/yyyyMMdd_nn_convert_pdf/{inputs,workspace}`）
2. **venv 構築**（`workspace/.venv` 配下）→ 依存パッケージをインストール
3. **Chromium インストール**（初回のみ、`playwright install chromium`）
4. **convert-html 経由で中間 HTML 生成**（一時ディレクトリに出力）
5. **Playwright で HTML を読み込み、PDF として保存**
6. **出力ファイルをユーザーに報告**（最終 PDF はセッションフォルダ直下）
7. **venv 削除**

詳細は [`references/procedures.md`](references/procedures.md)、環境構築は [`references/setup.md`](references/setup.md) を参照。

## アセットの場所

- 変換スクリプト: `${CLAUDE_SKILL_DIR}/scripts/convert/convert_pdf.py`
- 内部依存: 同一プラグイン内の `convert-html` スキルを subprocess で呼び出す
- HTML / CSS テンプレートは `convert-html` 経由で `${CLAUDE_PLUGIN_ROOT}/assets/` から解決される

## オプション

| オプション | 省略値 | 内容 |
|-----------|-------|------|
| `--title` | MD 内の最初の H1 | ドキュメントタイトル |
| `--format` | `A4` | 用紙サイズ（`A4`, `A3`, `Letter` など） |
| `--landscape` | なし | 横向きに切り替え |
| `--margin` | `20mm` | 全辺の余白（`top right bottom left` 個別指定も可） |
| `--no-background` | なし | 背景色を印刷しない（モノクロ印刷向け） |

## 重要な制約

- convert-html スクリプトの解決順は `$CONVERT_HTML_SCRIPT` → `$CLAUDE_PLUGIN_ROOT` → 同一プラグイン内兄弟ディレクトリ
- いずれの解決でも convert-html が見つからない場合は `sys.exit(1)` で停止
- Playwright の `browser.close()` は `try/finally` で保護され、PDF 生成例外時もリソースリークしない
- 中間 HTML は `tempfile.TemporaryDirectory()` 配下に作成され処理完了時に自動削除
- `subprocess.run(..., shell=False)` を使用し、シェル注入を回避

## 依存スキル

- `convert-html`（同一プラグイン内）— HTML 生成のために subprocess で呼び出す

## 参照

| 用途 | ファイル |
|-----|---------|
| 環境構築 | [`references/setup.md`](references/setup.md) |
| 変換実行手順 | [`references/procedures.md`](references/procedures.md) |
| 動作分岐の期待挙動ケース | [`evals/`](evals/) |
