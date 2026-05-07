# convert-doc

Markdown ファイルを Wiki スタイルで **HTML / PDF / PowerPoint（PPTX）** のいずれにも変換できる、3 スキル + 4 コマンド同梱の配布用プラグイン。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は各スキルの `SKILL.md` および `references/` 配下を参照してください。

## 提供スキル

| スキル | 役割 | 代表的なトリガーフレーズ |
|-------|------|-----------------------|
| `convert-html` | Markdown → 自己完結型 HTML | 「MD を HTML に変換」「資料を HTML で出力」 |
| `convert-pdf` | Markdown → PDF（内部で HTML 経由） | 「MD を PDF に変換」「資料を PDF で出力」 |
| `convert-pptx` | Markdown → PowerPoint スライド | 「MD を PowerPoint に変換」「設計書をスライドにして」 |

3 スキルは共通のデザイントーン（ネイビー #003879 基調）で出力する。

## 導入手順

### A. マーケットプレイス経由でインストール（推奨）

`dmajima-claude-plugins` マーケットプレイスがすでに登録されている場合:

```text
/plugin install convert-doc@dmajima-claude-plugins
```

未登録の場合はマーケットプレイス追加から:

```text
/plugin marketplace add dmajima/claude-plugins
/plugin install convert-doc@dmajima-claude-plugins
```

### B. ローカル複製でインストール

リポジトリをクローンしてローカルマーケットプレイスとして登録:

```bash
git clone https://github.com/dmajima/claude-plugins.git
```

```text
/plugin marketplace add /path/to/claude-plugins
/plugin install convert-doc@dmajima-claude-plugins
```

### C. 自動更新の有効化

`~/.claude/settings.json` に以下を追記すると、Claude Code 起動時に最新バージョンへ自動更新されます。

```json
{
  "extraKnownMarketplaces": {
    "dmajima-claude-plugins": {
      "source": {
        "type": "github",
        "owner": "dmajima",
        "repo": "claude-plugins"
      },
      "autoUpdate": true
    }
  }
}
```

### D. 依存関係のインストール

3 スキルとも Python 仮想環境を利用します。スキル初回起動時に `scripts/setup/setup_venv.sh` が自動実行され、以下の依存パッケージがインストールされます。

| スキル | 主要パッケージ | 追加ダウンロード |
|-------|--------------|----------------|
| convert-html | markdown / Pygments / rcssmin / rjsmin / Pillow | なし |
| convert-pdf | playwright / markdown / Pygments / rcssmin / rjsmin / Pillow | Chromium バイナリ（~120MB、初回のみ） |
| convert-pptx | python-pptx / Pillow / requests / Pygments | なし |

すべてピン固定（`==`）バージョンで管理されています。バージョンは各スキルの `scripts/setup/requirements.txt` を参照してください。

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

- 各 `## 見出し` ごとに 1 スライドを生成（1 枚目は `# タイトル` をタイトルスライドに）
- mermaid 図は PNG で取得してスライドに配置
- コードブロックはモノスペースフォントのテキストフレームとして配置
- 表は PowerPoint ネイティブの表として配置
- タイトル帯・装飾はネイビーカラーを使用

## ファイル構成

```
plugins/convert-doc/
├── .claude-plugin/
│   └── plugin.json
├── README.md                         # このファイル（人間向け）
├── commands/                         # スラッシュコマンド
│   ├── convert-html.md
│   ├── convert-html-full.md
│   ├── convert-pdf.md
│   └── convert-pptx.md
├── assets/                           # プラグイン共通 assets（ADR-001 参照）
│   ├── css/
│   │   └── template.css
│   └── html/
│       └── template.html
└── skills/
    ├── convert-html/
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── assets/                   # convert-html 固有 assets（ADR-002 参照）
    │   │   └── js/
    │   ├── evals/                    # 動作分岐の期待挙動ケース
    │   ├── references/
    │   └── scripts/
    ├── convert-pdf/
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── evals/
    │   ├── references/
    │   └── scripts/
    └── convert-pptx/
        ├── SKILL.md
        ├── README.md
        ├── evals/
        ├── references/
        └── scripts/
```

## 設計上の決定（ADR）

### ADR-001: プラグイン直下 `assets/` の採用

| 項目 | 内容 |
|------|------|
| 状態 | Accepted |
| 決定 | プラグイン直下に `assets/` を置き、HTML/PDF 共通の CSS / HTML テンプレートを格納する |
| 文脈 | `convert-html` と `convert-pdf` は同一の HTML 表現を共有するため、CSS / HTML テンプレートを 2 箇所で重複保持すると DRY 違反になる |
| 代替案 | 各スキルに完全コピー（重複・同期保守コスト高） |
| トレードオフ | プラグイン構造規約の許可リスト（`SKILL.md` `commands/` `agents/` `hooks/` `mcp/` `references/` `skills/` `.claude-plugin/`）を逸脱するが、共通リソースの SSOT 化を優先する |

### ADR-002: スキル直下 `assets/` の採用

| 項目 | 内容 |
|------|------|
| 状態 | Accepted |
| 決定 | スキル直下に `assets/` を置き、該当スキル固有の JS / CSS / HTML を格納する。同名ファイルが存在する場合はスキル側が ADR-001 のプラグイン共通アセットを上書きする |
| 文脈 | `convert-html` 固有の対話 JS（`lightbox.js` `toc-toggle.js` `features.json`）はプラグイン共通には属さない。また、特定のスキルだけで CSS を上書きしたい運用ニーズがある |
| 代替案 | スキル固有 JS を `references/template/` 等の既存ディレクトリに混在させる（責務不明瞭） |
| トレードオフ | スキル構造規約の許可リスト（`SKILL.md` `README.md` `references/` `scripts/` `agents/` `evals/`）を逸脱するが、ADR-001 と整合する形で固有資産の置き場として明示する |

### ADR-003: convert-pdf が convert-html へ subprocess 越しに依存

| 項目 | 内容 |
|------|------|
| 状態 | Accepted |
| 決定 | convert-pdf は convert-html の `convert.py` を subprocess で呼び出し、HTML 生成ロジックを SSOT に保つ |
| 文脈 | HTML 生成ロジックを HTML / PDF で重複実装すると、デザイン更新時に両方修正が必要になる |
| 解決順序 | パス解決は `$CONVERT_HTML_SCRIPT` → `$CLAUDE_PLUGIN_ROOT` → 同一プラグイン内兄弟ディレクトリ の優先順位（`convert_pdf.py:locate_convert_html_script`）|
| 代替案 | convert-html をライブラリ化して import / Skill ツール経由（subprocess 内では呼べない） |
| トレードオフ | プロセス起動オーバーヘッドが発生するが、依存方向の単純さを優先する |

### ADR-004: venv 構築/撤去スクリプトをスキル内に保持

| 項目 | 内容 |
|------|------|
| 状態 | Accepted |
| 決定 | 各スキル配下に `scripts/setup/setup_venv.sh` `teardown_venv.sh` `requirements.txt` を保持する |
| 文脈 | `environment-setup-toolkit` への委譲は extension-toolkit 環境に依存するが、本プラグインは単体配布の簡便性を優先する |
| 代替案 | extension-toolkit に環境構築を委譲（依存プラグインが増える） |
| トレードオフ | 各スキルで類似コードが重複するが、スキル単独の再利用性を優先する |

## 依存システム（External Dependencies）

本プラグインの 3 スキルは、変換処理のために以下の外部サービスへアクセスする。

| 依存先 | 用途 | 影響するスキル | オフライン時の挙動 |
|-------|------|-------------|------------------|
| `https://mermaid.ink/svg/{base64url}` | mermaid を SVG に変換（HTML / PDF 用） | convert-html, convert-pdf | 3 回リトライ後 `<div class="mermaid-error">` を出力（コードはエスケープされたまま表示） |
| `https://mermaid.ink/img/{base64url}?type=png` | mermaid を PNG に変換（PPTX 用） | convert-pptx | mermaid 図はテキストコードブロックとしてフォールバック |
| `https://fonts.googleapis.com/css2?family=Lato` | 本文フォントの読み込み（HTML / PDF 用） | convert-html, convert-pdf | システムフォント（ヒラギノ角ゴ Pro W3 等）にフォールバック |

- mermaid.ink のエンドポイントは各スクリプト内で定数として定義しているため、オフライン環境向けに差し替え可能。
- convert-pdf は初回実行時に Playwright が Chromium をダウンロードする（~120MB）。

## カスタマイズ

- HTML / PDF のデザイン変更（共通）: `plugins/convert-doc/assets/css/template.css` を編集するか、同ディレクトリに追加の `.css` ファイルを置く（2 ファイル以上ある場合はスキル実行時に選択プロンプトが表示される）
- convert-html / convert-pdf だけで上書きしたい場合: `skills/{skill-name}/assets/css/` に同名ファイルを置く（スキル側がプラグイン共通を上書きする）
- PPTX の色・フォント・レイアウト変更: `skills/convert-pptx/scripts/convert/convert_pptx.py` 冒頭の定数を編集
- Python 依存パッケージの更新: 各スキルの `scripts/setup/requirements.txt` を編集

## ライセンス

[MIT License](LICENSE) の下で配布されています。
