---
name: convert-html
description: >
  MarkdownファイルをWikiスタイルのデザインが適用された自己完結型HTMLファイルに変換するスキル。
  画像はbase64埋め込み、mermaid図はSVG変換・インライン埋め込み、コードブロックにはシンタックスハイライトが適用される。
  「MDをHTMLに変換」「MarkdownからHTML」「HTMLファイルに書き出して」「設計書をHTMLに変換して」
  「資料をHTMLで出力して」「convert-html」などの依頼に必ず使用すること。
---

# convert-html スキル

MarkdownファイルをWikiデザインの自己完結型HTMLに変換する。

## 出力の特徴

- HTMLファイル1つで完結（外部ファイル参照なし）
- 画像をbase64埋め込み・クリックでライトボックスポップアップ表示（ズーム・パン対応）
- mermaid図をSVG変換して埋め込み（横スクロール対応・クリックで拡大表示）
- `~~打ち消し線~~` をHTMLの `<del>` タグに変換（GFM互換）
- Pygmentsによるシンタックスハイライト
- 本文先頭の手書き `## 目次` セクションを自動除去
- 右スティッキーサイドバーに自動生成目次（リンクなしテキスト表示、H2〜H6対象）
- Wikiトンマナのデザイン（ネイビー #003879 基調）

## 実行フロー

1. **ワークディレクトリ作成**（`.claude/.local/work/yyyyMMdd_nn_convert_html/{inputs,workspace}`）
2. **venv構築**（`workspace/.venv` 配下）→ 依存パッケージをインストール
3. **変換スクリプト実行**
4. **出力ファイルをユーザーに報告**（最終HTMLはセッションフォルダ直下）
5. **venv削除**

詳細な実行手順は `references/procedures.md`、環境構築（venv・依存パッケージ）は `references/setup.md` を参照。

## アセットの場所

変換スクリプトは **スキル側の同名パスを優先** し、なければ **プラグイン共通** にフォールバックする。
スキル固有にカスタマイズしたい場合は、対応する相対パスのファイルを `${CLAUDE_SKILL_DIR}/assets/...` に置けば上書きされる。

| アセット | 既定の配置 | 分類 |
|---------|-----------|------|
| 変換スクリプト | `${CLAUDE_SKILL_DIR}/scripts/convert/convert.py` | スキル固有 |
| HTML テンプレート | `${CLAUDE_PLUGIN_ROOT}/assets/html/template.html` | プラグイン共通（PDF と共有） |
| CSS テンプレート | `${CLAUDE_PLUGIN_ROOT}/assets/css/template.css` | プラグイン共通（PDF と共有） |
| ライトボックス JS | `${CLAUDE_SKILL_DIR}/assets/js/lightbox.js` | スキル固有（HTML 専用） |
| 目次トグル JS | `${CLAUDE_SKILL_DIR}/assets/js/toc-toggle.js` | スキル固有（HTML 専用） |
| JS 機能カタログ | `${CLAUDE_SKILL_DIR}/assets/js/features.json` | スキル固有（HTML 専用） |

## CSSファイルの選択（複数存在する場合）

スキル実行前に `${CLAUDE_SKILL_DIR}/assets/css/` とフォールバック先の `${CLAUDE_PLUGIN_ROOT}/assets/css/` の `.css` ファイルを合算して確認し、**2つ以上存在する場合**は `AskUserQuestion` ツールで選択させる。同名ファイルはスキル側を優先する。

### 呼び出し方針

- `question`: `"適用するCSSを選択してください。"`
- `header`: `"CSS"`
- `multiSelect`: `false`（1つだけ選択）
- `options`: 検出した `.css` ファイルを `{ label: ファイル名, description: "<由来> の <ファイル名> を使用" }` で列挙（由来は「スキル」または「プラグイン共通」）

### 回答の処理

- 選択されたファイルの **絶対パス** を `--css-template "<絶対パス>"` として渡す（由来に応じて `${CLAUDE_SKILL_DIR}/assets/css/...` または `${CLAUDE_PLUGIN_ROOT}/assets/css/...` を解決した結果）
- 「Other」（カスタム指示）が入力された場合は、入力内容を指示として解釈して処理する
- **回答受け取り後、確認なしでそのまま処理を続行する**

### 制約

- `AskUserQuestion` の options は最大4件（「Other」は自動付与のため実質3件）。CSS ファイルが4件以上の場合はテキストベースの選択に切り替える
- `${CLAUDE_SKILL_DIR}/assets/css/` と `${CLAUDE_PLUGIN_ROOT}/assets/css/` の合算で `.css` ファイルが1つだけの場合は選択肢を提示せずにそのまま使用する（同名ファイルがある場合はスキル側を優先）

## JS機能の選択

スキル実行前に `${CLAUDE_SKILL_DIR}/assets/js/features.json` を読み込み、**1つ以上の機能が登録されている場合**は `AskUserQuestion` ツールで確認する。機能を省くことでファイルサイズを削減できるため、1機能のみでも必ず確認する。

### 呼び出し方針

デフォルトは全機能有効のため、**除外したい機能を選択する方式**で質問する。

- `question`: `"除外するJS機能を選択してください。（何も選択しない → 全機能有効）"`
- `header`: `"JS機能"`
- `multiSelect`: `true`
- `options`: features.json の各機能を `{ label: 機能名, description: 説明文 }` で列挙したあと、末尾に以下を追加する
  - `{ label: "全て不要", description: "JSを一切埋め込まない" }`

### 回答の処理

1. 回答文字列を `,` で分割し、各要素を trim して**空文字・空白のみの要素は除外**する
2. 「全て不要」が含まれる場合は `--js-features ""` を渡して処理を続行する
3. それ以外は残った要素を除外対象の機能名リストとし、features.json の全機能から差し引いた機能のファイル名をカンマ結合して `--js-features` に渡す
4. **回答受け取り後、確認なしでそのまま処理を続行する**

### 制約

- `AskUserQuestion` の options は最大4件（「全て不要」を含む）。features.json の機能が3件以上になる場合はテキストベースの選択に切り替える
- **別スキルからの呼び出しなど対話が難しい場合は `--js-features` を省略して全機能を導入する**

JS機能ファイルの作成・追加ルールは `references/js-authoring.md` を参照。
