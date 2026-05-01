# convert-html 実行手順

環境構築（venv・依存パッケージ）は `setup.md` を参照すること。

## 変換スクリプト実行

スキル自身のスクリプトは `${CLAUDE_SKILL_DIR}` 経由で参照する。

```bash
"$SESSION_DIR/workspace/.venv/Scripts/python" \
  "${CLAUDE_SKILL_DIR}/scripts/convert/convert.py" \
  "<入力MDファイルパス>" \
  "<出力HTMLファイルパス>" \
  [--title "タイトル文字列"]
```

- `--title` は省略可能（省略時はMD内の最初のH1見出しを使用）
- `--html-template` は省略可能（省略時は skill→plugin の順で `assets/html/template.html` を解決）
- `--css-template` は省略可能（省略時は skill→plugin の順で `assets/css/template.css` を解決）
- `--js-features` は省略可能（省略時は `features.json` に登録された全機能を使用）
  - 例: `--js-features lightbox.js` （ライトボックスのみ）
  - 例: `--js-features lightbox.js,other.js` （複数指定、カンマ区切り）
  - 機能なし: `--js-features ""` （JSなし）
- 出力先が未指定の場合、入力ファイルと同ディレクトリ・同名で `.html` 拡張子で出力

## 出力先の決定ルール

| ユーザー指定 | 出力先 |
|---|---|
| 出力パスを明示指定 | 指定パス |
| 出力パスなし | 入力MDファイルと同ディレクトリに `<stem>.html` |
| ワークディレクトリへの出力を希望 | `.claude/.local/work/yyyyMMdd_nn_convert_html/<stem>.html`（最終成果物はセッションフォルダ直下） |

## convert.py の変換処理フロー

スクリプト内部で以下の順に処理する。

1. **打ち消し線前処理** — `~~text~~` → `<del>text</del>`（python-markdown非対応のため）
2. **手書き目次除去** — `## 目次` セクションを本文から削除（サイドバーTOCで代替）
3. **mermaid前処理** — `\n`（バックスラッシュ+n）を `<br/>` に変換してからAPIに送信
4. **mermaid → SVG変換** — `mermaid.ink` API に送信（最大3回リトライ・2秒間隔）
5. **Markdown → HTML変換** — python-markdown（tables / fenced_code / codehilite / toc / sane_lists）
6. **プレースホルダー復元** — SVGをbodyに埋め込み
7. **ローカル画像base64埋め込み**
8. **H1除去** — `doc-title` として別途表示するため本文から削除
9. **TOCリンク除去** — サイドバーTOCの `<a>` タグを除去してテキストのみ表示
10. **HTML組み立て** — CSS + Pygments CSS + 選択されたJSフィーチャーをインライン埋め込み

## Mermaid 変換について

- `mermaid.ink` API（`https://mermaid.ink/svg/{base64url}`）を使用
- インターネット接続が必要
- 変換失敗時はエラーメッセージを `<div class="mermaid-error">` として出力
- 通常表示は横スクロール対応（SVGは縮小せず自然サイズで表示）
- クリックでライトボックスポップアップ（ズーム・パン可能）

## ライトボックス操作

生成されたHTMLにインラインで埋め込まれる。外部ライブラリ不要。

| 操作 | 動作 |
|---|---|
| 画像 / Mermaid図をクリック | ポップアップ表示 |
| マウスホイール | ズームイン/アウト |
| ドラッグ | 移動（パン） |
| ダブルクリック | ズームリセット |
| Esc / ×ボタン / 背景クリック | 閉じる |

## アセットの場所

convert.py は各アセットを以下の順序で解決する（先に見つかったものを使う）:

1. スキル側の同名パス（`${CLAUDE_SKILL_DIR}/assets/...`）— 上書き
2. プラグイン共通（`${CLAUDE_PLUGIN_ROOT}/assets/...`）— フォールバック

| ファイル | 既定の配置 | 分類 |
|---|---|---|
| HTMLテンプレート | `${CLAUDE_PLUGIN_ROOT}/assets/html/template.html` | プラグイン共通（PDF と共有） |
| CSSテンプレート | `${CLAUDE_PLUGIN_ROOT}/assets/css/template.css` | プラグイン共通（PDF と共有） |
| ライトボックス JS | `${CLAUDE_SKILL_DIR}/assets/js/lightbox.js` | スキル固有（HTML 専用） |
| 目次トグル JS | `${CLAUDE_SKILL_DIR}/assets/js/toc-toggle.js` | スキル固有（HTML 専用） |
| JS 機能カタログ | `${CLAUDE_SKILL_DIR}/assets/js/features.json` | スキル固有（HTML 専用） |

- **HTMLテンプレート**: 生成 HTML の骨格。`{{PLACEHOLDER}}` 形式のプレースホルダーを使用。削除したプレースホルダーは挿入されない。
- **CSSテンプレート**: Wiki デザインを模倣したスタイルシート。デザイン変更はこのファイルを編集する（HTML/PDF 両方に反映）。
- **ライトボックス JS**: 画像・Mermaid 図のポップアップ表示用。IIFE 形式で単独動作。
- **スキル側で上書きしたい場合**: 同じ相対パス（例: `${CLAUDE_SKILL_DIR}/assets/css/template.css`）にファイルを置けば、そのスキル限定で上書きされる。

## 目次サイドバーの仕様

- H2〜H6を対象に自動生成（H1はdoc-titleで表示するため除外）
- 右側に sticky 表示（スクロールに追随）
- テキストのみ（アンカーリンクなし）
- 幅24rem、フォント1.2rem
- 1024px以下でカラムレイアウトに切替（本文上部に移動）
