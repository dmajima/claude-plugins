# convert-html スキル

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は `SKILL.md` および `references/` 配下を参照してください。

## 概要

Markdown ファイルを Wiki スタイルのデザインが適用された自己完結型 HTML ファイルに変換するスキル。
変換後の HTML は外部ファイルへの依存なしに単体で機能し、要件定義資料・設計書・お客様向け提出物として使用できる。

## 導入手順

本スキルは `convert-doc` プラグインに同梱されています。プラグインのインストール方法はリポジトリルートの [`README.md`](../../../../README.md) を参照してください。

```text
/plugin install convert-doc@dmajima-claude-plugins
```

依存パッケージ（markdown / Pygments / rcssmin / rjsmin / Pillow）は初回実行時に `references/scripts/setup/setup_venv.sh` が自動で venv を構築してインストールします。

## 使い方

### トリガーフレーズ（例）

- 「このMarkdownをHTMLに変換して」
- 「MDをHTMLに書き出して」
- 「設計書をHTMLファイルにして」
- 「資料をHTMLで出力して」
- 「convert-html で変換して」

### 入力

- 変換対象の Markdown ファイルのパス（または現在の作業ファイル）

### 出力

```
.claude/.local/work/20260408_01_convert_html/
├── {元ファイル名}.html        # 自己完結型 HTML（最終成果物・直下）
├── inputs/                    # （任意）ユーザー提供の元 Markdown
└── workspace/
    └── .venv/                 # Python venv（処理後削除）
```

### 出力 HTML の特徴

| 機能 | 内容 |
|------|------|
| 自己完結 | 外部ファイル参照なし・単一ファイルで完結 |
| 画像埋め込み | base64 エンコードで HTML に埋め込み |
| mermaid 図 | SVG 変換・インライン埋め込み（横スクロール・クリック拡大対応） |
| 打ち消し線 | `~~テキスト~~` を `<del>` タグに変換（GFM 互換） |
| シンタックスハイライト | Pygments によるコードブロック着色 |
| 目次自動生成 | 右サイドバーに H2〜H6 の目次を自動表示（ドキュメント型のみ） |
| テンプレート形態 | **ドキュメント型**（`template.css`: Wiki トンマナ・ネイビー #003879 基調・縦長資料）と **Web ページ型・経営者向け**（`executive.css`: ネイビー #0B2E59 ×ゴールド #B8933E・LP 風レイアウト）の 2 種類 |
| Web ページ型の生成物 | `--split-sections` により h2 単位で全幅セクションに分割し、ネイビーのヒーローヘッダー・ゴールドの章番号付き交互背景セクション・スリムなページフッターを自動生成。目次は `toc-toggle.js`（サイドバー/ドロワー）、`scroll-reveal.js` でスクロール時のフェードイン演出 |

## 動作例

```
ユーザー: 「要件定義書.md を HTML に変換して」

Claude の動作:
  1. venv を構築（.claude/.local/work/20260408_01_convert_html/workspace/.venv）
  2. CSSファイルが複数ある場合: AskUserQuestion UI（ラジオボタン）で選択させる
  3. JS機能の選択: AskUserQuestion UI（チェックボックス）で除外機能を選択させる
     ※ 何も選ばない = 全機能有効 / 「全て不要」を選択 = JS埋め込みなし
  4. references/scripts/convert-html/convert.py を実行
  5. 出力パスを報告
  6. venv を削除

出力: .claude/.local/work/20260408_01_convert_html/要件定義書.html
```

## カスタマイズ・拡張

### CSS テーマを追加する

CSS / HTML テンプレートは **プラグイン共通** として `plugins/convert-doc/assets/css/` に置かれており、
convert-html と convert-pdf が同じファイルを参照する。

1. **全スキルに反映したい場合**: `plugins/convert-doc/assets/css/` に新しい `.css` ファイルを追加する
2. **convert-html だけに反映したい場合**: `skills/convert-html/assets/css/` に新しい `.css` ファイルを追加する（スキル側の同名ファイルはプラグイン共通を上書きする）
3. 複数 CSS が存在する場合は、スキル実行時に自動的に選択肢として提示される
4. 対になる HTML 骨格・追加フラグが必要なテンプレート（例: `executive.css` → `executive.html` + `--split-sections`）は `references/css-js-selection.md` の「CSS と HTML 骨格のペアリング」表に登録する

```
plugins/convert-doc/
├── assets/css/
│   ├── template.css          # ドキュメント型デフォルトテーマ（HTML と PDF 両方が使う）
│   └── executive.css         # Web ページ型・経営者向けテーマ（executive.html とペア）
└── skills/convert-html/assets/css/
    └── dark-theme.css        # convert-html 限定の追加テーマ（例）
```

経営者向け Web ページ型のトンマナ変更は `executive.css` 冒頭の CSS カスタムプロパティ
（`--exec-primary` / `--exec-accent` 等）を編集する。同一トンマナの PPTX（スライド）版は
`convert-pptx` スキルの `--theme executive`（`convert_pptx.py` の `THEMES` 辞書）が対応する。

### JS 機能を追加する

JS アセットは **convert-html 固有** のため `skills/convert-html/assets/js/` に配置する（PDF では意味を持たない）。

1. `skills/convert-html/assets/js/` に JS ファイルを追加する
2. `skills/convert-html/assets/js/features.json` に機能情報を登録する

```json
{
  "features": [
    {
      "name": "ライトボックス",
      "file": "lightbox.js",
      "description": "画像・Mermaid図をクリックでポップアップ表示（ズーム・パン対応）"
    },
    {
      "name": "新機能名",
      "file": "new-feature.js",
      "description": "機能の説明"
    }
  ]
}
```

JS ファイルの作成ルールは `references/template/js-feature-template.js` を参照。
詳細は `references/js-authoring.md` を参照。

### HTML テンプレートを変更する

- 全スキル共通で変更する場合: `plugins/convert-doc/assets/html/template.html`（ドキュメント型）または `plugins/convert-doc/assets/html/executive.html`（Web ページ型）を編集
- convert-html だけで上書きする場合: `skills/convert-html/assets/html/template.html` を作成（スキル側が優先される）
- CSS も同様に `plugins/convert-doc/assets/css/` 側か `skills/convert-html/assets/css/` 側を編集

### 変換スクリプトを変更する

- `references/scripts/convert-html/convert.py` を編集する（セクション分割は `split_body_into_sections()`）
- 依存パッケージを追加する場合は `references/scripts/setup/requirements.txt` も更新する

## ファイル構成

```
convert-html/
├── SKILL.md                          # Claude が実行時に読み込むスキル定義
├── README.md                         # 本ファイル（人間向けリファレンス）
├── assets/
│   └── js/                           # スキル固有 assets（HTML 専用 JS）
│       ├── features.json             # JS 機能の登録ファイル
│       ├── lightbox.js               # ライトボックス機能
│       ├── scroll-reveal.js          # スクロールリビール機能（Web ページ型用）
│       └── toc-toggle.js             # 目次トグル機能
├── evals/                            # 動作分岐の期待挙動ケース
└── references/
    ├── setup.md                      # 環境構築手順（Claude 参照用）
    ├── procedures.md                 # 変換実行手順（Claude 参照用）
    ├── css-js-selection.md           # CSS / JS の対話選択・ペアリング規則（Claude 参照用）
    ├── js-authoring.md               # JS 機能の作成ルール（Claude 参照用）
    └── template/
        └── js-feature-template.js    # JS 機能テンプレート
```

CSS と HTML テンプレート・変換スクリプト（`references/scripts/convert-html/convert.py`）・
venv 構築スクリプト（`references/scripts/setup/`）は **プラグイン共通** のため
`plugins/convert-doc/` 直下に配置されている。
詳細は `plugins/convert-doc/README.md` の「ADR-001: プラグイン直下／スキル直下 `assets/` の採用」を参照。
