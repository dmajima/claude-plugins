---
name: convert-html
description: Markdown ファイルを Wiki スタイルの自己完結型 HTML に変換するスキル（画像 base64 埋込・mermaid SVG インライン・シンタックスハイライト適用）。「MD を HTML に変換」「設計書を HTML に変換」「資料を HTML で出力」等で起動する。Use when converting a Markdown file into a self-contained styled HTML. SKIP when target format is PDF (convert-pdf) or PowerPoint (convert-pptx).
---

# convert-html スキル

Markdown ファイルを Wiki デザインの自己完結型 HTML に変換する。

## 責務

- Markdown → 自己完結型 HTML への変換（外部参照なし、画像 base64・mermaid SVG インライン埋め込み）
- CSS テンプレート（プラグイン共通 + スキル固有の合算）の選択と適用
- JS 機能（features.json に登録されたもの）の選択と埋め込み
- 自動目次生成（右スティッキーサイドバー）

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| HTML → PDF への変換 | `convert-pdf`（内部で本スキルを呼び出す） |
| HTML → PPTX への変換 | `convert-pptx`（独自パイプライン） |
| 画像生成・mermaid 描画基盤の構築 | 本スキル外（`mermaid.ink` 外部 API に依存） |

## トリガー条件

以下のいずれかに該当する場合に起動する。

- 「MD を HTML に変換」「Markdown を HTML 化」「設計書を HTML で出力」等の自然言語依頼
- `/convert-html` または `/convert-html-full` スラッシュコマンド
- 他スキルからの `Skill(skill: "convert-html", ...)` 呼び出し

このスキルを起動しないケース:

- 既に HTML が指定されている場合（再変換不要）
- PDF / PPTX への変換依頼（`convert-pdf` / `convert-pptx` へルーティング）

## 前提

- 入力 Markdown ファイルがローカルに存在し読み取り可能
- Python 3.9+ が利用可能
- 初回起動時はインターネット接続あり（Pillow / markdown 等のパッケージインストール用）
- mermaid 図を含む場合は `mermaid.ink` への HTTPS 接続（オフライン時はエラーブロック出力にフォールバック）

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `/convert-html-full` | 非対話 | CSS / JS の対話プロンプトを出さず全機能有効で処理 |
| 別スキルからの `Skill(...)` 呼び出し | 非対話 | `--js-features` 省略で全機能、CSS は first-existing |
| `/convert-html` または自然言語依頼 | 対話 | CSS 複数なら選択 UI、JS 機能カタログがあれば除外選択 UI |

## 実行フロー

1. **ワークディレクトリ作成**（`.claude/.local/work/yyyyMMdd_nn_convert_html/{inputs,workspace}`）
2. **venv 構築**（`workspace/.venv` 配下）→ 依存パッケージをインストール
3. **CSS / JS の選択**（対話モード時のみ。詳細は [`references/css-js-selection.md`](references/css-js-selection.md)）
4. **変換スクリプト実行**（`references/scripts/convert-html/convert.py`）
5. **出力ファイルをユーザーに報告**（最終 HTML はセッションフォルダ直下）
6. **venv 削除**

詳細な実行手順は [`references/procedures.md`](references/procedures.md)、環境構築（venv・依存パッケージ）は [`references/setup.md`](references/setup.md) を参照。

## アセットの場所

変換スクリプトは **スキル側の同名パスを優先** し、なければ **プラグイン共通** にフォールバックする。

| アセット | 既定の配置 | 分類 |
|---------|-----------|------|
| 変換スクリプト | `${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-html/convert.py` | スキル固有 |
| HTML テンプレート | `${CLAUDE_PLUGIN_ROOT}/assets/html/template.html` | プラグイン共通（PDF と共有） |
| CSS テンプレート | `${CLAUDE_PLUGIN_ROOT}/assets/css/template.css` | プラグイン共通（PDF と共有） |
| ライトボックス JS | `${CLAUDE_SKILL_DIR}/assets/js/lightbox.js` | スキル固有（HTML 専用） |
| 目次トグル JS | `${CLAUDE_SKILL_DIR}/assets/js/toc-toggle.js` | スキル固有（HTML 専用） |
| JS 機能カタログ | `${CLAUDE_SKILL_DIR}/assets/js/features.json` | スキル固有（HTML 専用） |

スキル固有にカスタマイズしたい場合は、対応する相対パスのファイルを `${CLAUDE_SKILL_DIR}/assets/...` に置けば上書きされる。

## 重要な制約

- 中間生成物・venv は `workspace/` 配下に置き、最終 HTML はセッションフォルダ直下に配置する
- 入力ファイルパスは `inputs/` 配下に置かれている場合は読み取り専用として扱う
- `--js-features` で渡されるファイル名に `..` `/` `\` が含まれる場合は拒否する（パストラバーサル対策）
- 画像 `src` がローカルパスの場合、解決後のパスが `base_dir` 配下であることを検証する（パストラバーサル対策）
- mermaid.ink のレスポンスは Content-Type が `image/svg+xml` であり、かつ先頭が `<svg` または `<?xml` で始まることを検証してから埋め込む
- mermaid 取得失敗時はエラー HTML（`html.escape` 済みの diagram code を含む）を出力して処理続行

## 参照

| 用途 | ファイル |
|-----|---------|
| 環境構築（venv・依存パッケージ） | [`references/setup.md`](references/setup.md) |
| 変換実行手順 | [`references/procedures.md`](references/procedures.md) |
| CSS / JS 機能の対話選択ルール | [`references/css-js-selection.md`](references/css-js-selection.md) |
| JS 機能の作成ルール | [`references/js-authoring.md`](references/js-authoring.md) |
| 動作分岐の期待挙動ケース | [`evals/`](evals/) |
