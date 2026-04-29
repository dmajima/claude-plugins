# convert-doc

Markdown ファイルを Wiki スタイルで **HTML / PDF / PowerPoint（PPTX）** のいずれにも変換できる、3 スキル同梱の配布用プラグイン。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。

## 提供スキル

| スキル | 役割 | 代表的なトリガーフレーズ |
|-------|------|-----------------------|
| `convert-html` | Markdown → 自己完結型 HTML | 「MD を HTML に変換」「資料を HTML で出力」 |
| `convert-pdf` | Markdown → PDF（内部で HTML 経由） | 「MD を PDF に変換」「資料を PDF で出力」 |
| `convert-pptx` | Markdown → PowerPoint スライド | 「MD を PowerPoint に変換」「設計書をスライドにして」 |

3 スキルは共通のデザイントーン（ネイビー #003879 基調）で出力する。

## 共通の特徴

- mermaid 図の自動描画（`mermaid.ink` API を利用）
- コードブロックのシンタックスハイライト
- 画像の埋め込み（HTML は base64、PDF/PPTX はバイト埋め込み）
- 表の可読性を維持したレイアウト

## 各形式の特徴

### HTML（`convert-html`）

- HTML 1 ファイルで完結（外部ファイル参照なし）
- 画像を base64 埋め込み・ライトボックス表示（ズーム・パン対応）
- mermaid 図を SVG に変換してインライン埋め込み
- 右スティッキーサイドバーに自動生成目次
- `~~打ち消し線~~` を `<del>` タグに変換（GFM 互換）

### PDF（`convert-pdf`）

- 内部で `convert-html` を実行し、生成された HTML を Chromium（Playwright）経由で PDF 化
- A4 縦・背景色印刷ありがデフォルト
- 表・mermaid・コードブロックのデザインは HTML と完全一致

### PPTX（`convert-pptx`）

- 各 `## 見出し` ごとに 1 スライドを生成（1枚目は `# タイトル` をタイトルスライドに）
- mermaid 図は PNG で取得してスライドに配置
- コードブロックはモノスペースフォントのテキストフレームとして配置
- 表は PowerPoint ネイティブの表として配置
- タイトル帯・装飾はネイビーカラーを使用

## 使い方

### 自然言語

次のようなフレーズで各スキルが起動します。

```
この Markdown を HTML に変換して → convert-html
設計書を PDF にして            → convert-pdf
資料を PowerPoint に変換して   → convert-pptx
```

### スラッシュコマンド

| コマンド | 役割 | 備考 |
|---------|------|------|
| `/convert-html` | Markdown → 自己完結型 HTML（CSS / JS 機能を対話で選択） | 通常用途 |
| `/convert-html-full` | Markdown → HTML（**全 JS 機能有効・対話プロンプトなし**） | 自動化・全機能必須の場合 |
| `/convert-pdf` | Markdown → PDF（内部で HTML 経由） | A4 縦・背景色印刷ありが既定 |
| `/convert-pptx` | Markdown → PowerPoint スライド | 16:9・タイトル帯ネイビー |

利用例:

```
/convert-html ./要件定義.md
/convert-html-full ./要件定義.md ./要件定義.html --title "要件定義書"
/convert-pdf ./設計書.md --format A4 --landscape
/convert-pptx ./提案資料.md --aspect 16:9 --subtitle "2026年4月版"
```

### 他スキルからの呼び出し

```
Skill(skill: "convert-html", args: "<入力MD> <出力HTML> [--title <タイトル>]")
Skill(skill: "convert-pdf",  args: "<入力MD> <出力PDF>  [--title <タイトル>]")
Skill(skill: "convert-pptx", args: "<入力MD> <出力PPTX> [--title <タイトル>]")
```

## ファイル構成

```
plugins/convert-doc/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── commands/                # スラッシュコマンド
│   ├── convert-html.md
│   ├── convert-html-full.md
│   ├── convert-pdf.md
│   └── convert-pptx.md
├── assets/                  # プラグイン共通 assets（HTML/PDF 両方が使用）
│   ├── css/
│   │   └── template.css
│   └── html/
│       └── template.html
└── skills/
    ├── convert-html/
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── assets/          # convert-html 固有 assets（ブラウザ対話用 JS）
    │   │   └── js/
    │   ├── references/
    │   └── scripts/
    ├── convert-pdf/
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── references/
    │   └── scripts/
    └── convert-pptx/
        ├── SKILL.md
        ├── README.md
        ├── references/
        └── scripts/
```

### assets の階層ポリシー

| 分類 | 配置先 | 例 |
|-----|-------|---|
| プラグイン共通（複数スキルで同じものを使う） | `plugins/convert-doc/assets/` | `css/template.css`、`html/template.html` |
| スキル固有（単一スキルでのみ使う／共通を上書き） | `plugins/convert-doc/skills/{skill-name}/assets/` | `convert-html/assets/js/` |

`convert.py` はアセットを参照する際、まず **スキル側の同名パス** を探し、見つからなければ **プラグイン共通** にフォールバックします。スキル配下に同名のファイルを置けば、そのスキル限定で上書きされます。

## 依存システム（External Dependencies）

本プラグインの 3 スキルは、変換処理のために以下の外部サービスへアクセスする。オフライン環境では mermaid 図の描画およびフォント表示に影響する。

| 依存先 | 用途 | 影響するスキル |
|-------|------|-------------|
| `https://mermaid.ink/svg/{base64url}` | mermaid を SVG に変換（HTML / PDF 用） | convert-html, convert-pdf |
| `https://mermaid.ink/img/{base64url}?type=png` | mermaid を PNG に変換（PPTX 用） | convert-pptx |
| `https://fonts.googleapis.com/css2?family=Lato` | 本文フォントの読み込み（HTML / PDF 用） | convert-html, convert-pdf |

- mermaid.ink のエンドポイントは各スクリプト内で定数として定義しているため、オフライン環境向けに差し替え可能。
- convert-pdf は初回実行時に Playwright が Chromium をダウンロードする（~120MB）。

## カスタマイズ

- HTML / PDF のデザイン変更（共通）: `plugins/convert-doc/assets/css/template.css` を編集するか、同ディレクトリに追加の `.css` ファイルを置く（2 ファイル以上ある場合はスキル実行時に選択プロンプトが表示される）
- convert-html / convert-pdf だけで上書きしたい場合: `skills/{skill-name}/assets/css/` に同名ファイルを置く（スキル側がプラグイン共通を上書きする）
- PPTX の色・フォント・レイアウト変更: `skills/convert-pptx/scripts/convert/convert_pptx.py` 冒頭の定数を編集。
- Python 依存パッケージの更新: 各スキルの `scripts/setup/requirements.txt` を編集。
