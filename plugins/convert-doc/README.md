# convert-doc

Markdown と **HTML / PDF / PowerPoint（PPTX）** を相互変換できる、4 スキル + 5 コマンド同梱の配布用プラグイン。PPTX → Markdown の取り込み変換にも対応し、Claude が PowerPoint 資料を読み込める形に転記する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は各スキルの `SKILL.md` および `references/` 配下を参照してください。

## 提供スキル

| スキル | 役割 | 代表的なトリガーフレーズ |
|-------|------|-----------------------|
| `convert-html` | Markdown → 自己完結型 HTML | 「MD を HTML に変換」「資料を HTML で出力」 |
| `convert-pdf` | Markdown → PDF（内部で HTML 経由） | 「MD を PDF に変換」「資料を PDF で出力」 |
| `convert-pptx` | Markdown → PowerPoint スライド | 「MD を PowerPoint に変換」「設計書をスライドにして」 |
| `convert-from-pptx` | PowerPoint (PPTX) → Markdown 取り込み | 「PPTX を Markdown に変換」「スライドを読める形にして」 |

出力系の 3 スキル（HTML / PDF / PPTX）は共通のデザイントーン（ネイビー #003879 基調）で出力する。取り込みスキル（`convert-from-pptx`）は構造を Markdown に転記し、フロー図や SmartArt は Mermaid に変換する。

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

4 スキルとも Python 仮想環境を利用します。スキル初回起動時に `references/scripts/setup/setup_venv.ps1` が自動実行され、以下の依存パッケージがインストールされます。

| スキル | 主要パッケージ | 追加ダウンロード |
|-------|--------------|----------------|
| convert-html | markdown / Pygments / rcssmin / rjsmin / Pillow | なし |
| convert-pdf | playwright / markdown / Pygments / rcssmin / rjsmin / Pillow | Chromium バイナリ（~120MB、初回のみ） |
| convert-pptx | python-pptx / Pillow / requests / Pygments | なし |
| convert-from-pptx | python-pptx / Pillow / lxml | なし（オフラインで動作） |

すべてピン固定（`==`）バージョンで管理されています。バージョンは各スキルの `references/scripts/setup/requirements.txt` を参照してください。

## 使い方

### 自然言語

次のようなフレーズで各スキルが起動します。

```
この Markdown を HTML に変換して  → convert-html
設計書を PDF にして             → convert-pdf
資料を PowerPoint に変換して    → convert-pptx
この PPTX を Markdown に変換して → convert-from-pptx
スライドを読める形にして         → convert-from-pptx
```

### スラッシュコマンド

| コマンド | 役割 | 備考 |
|---------|------|------|
| `/convert-html` | Markdown → 自己完結型 HTML（CSS / JS 機能を対話で選択） | 通常用途 |
| `/convert-html-full` | Markdown → HTML（**全 JS 機能有効・対話プロンプトなし**） | 自動化・全機能必須の場合 |
| `/convert-pdf` | Markdown → PDF（内部で HTML 経由） | A4 縦・背景色印刷ありが既定 |
| `/convert-pptx` | Markdown → PowerPoint スライド | 16:9・タイトル帯ネイビー |
| `/convert-from-pptx` | PowerPoint (PPTX) → Markdown 取り込み | 画像は別ファイルに抽出、フロー図は Mermaid 化 |

利用例:

```
/convert-html ./要件定義.md
/convert-html-full ./要件定義.md ./要件定義.html --title "要件定義書"
/convert-pdf ./設計書.md --format A4 --landscape
/convert-pptx ./提案資料.md --aspect 16:9 --subtitle "2026年4月版"
/convert-from-pptx ./受領資料.pptx ./受領資料.md --include-notes
```

### 他スキルからの呼び出し

```
Skill(skill: "convert-html",      args: "<入力MD> <出力HTML> [--title <タイトル>]")
Skill(skill: "convert-pdf",       args: "<入力MD> <出力PDF>  [--title <タイトル>]")
Skill(skill: "convert-pptx",      args: "<入力MD> <出力PPTX> [--title <タイトル>]")
Skill(skill: "convert-from-pptx", args: "<入力PPTX> <出力MD> [--include-notes] [--no-mermaid]")
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

### PPTX → Markdown（`convert-from-pptx`）

- 各スライドを `## スライドタイトル` セクションとして転記（1 枚目は `# タイトル`）
- テキスト・箇条書き（レベル保持）・装飾（太字 / 斜体 / 取消線）・モノスペース段落（コードブロック）を保持
- 表は Markdown パイプ表に変換
- 画像はバイナリで抽出し、出力 MD と同階層の `<basename>_images/` に保存。Markdown では相対パス参照
- 図形 + コネクタで構成されるフロー図は Mermaid `flowchart` に変換
- SmartArt は内部の `diagramData` XML を解析して Mermaid `flowchart` に変換（解析可能な範囲）
- スピーカーノートは `--include-notes` 指定時のみ `> [!NOTE]` ブロックで出力
- オフラインで完結（外部 API へのアクセスなし）

## ファイル構成

```
plugins/convert-doc/
├── .claude-plugin/
│   └── plugin.json
├── LICENSE
├── README.md                         # このファイル（人間向け）
├── commands/                         # スラッシュコマンド
│   ├── convert-html.md
│   ├── convert-html-full.md
│   ├── convert-pdf.md
│   ├── convert-pptx.md
│   └── convert-from-pptx.md
├── assets/                           # プラグイン共通 assets（extension-toolkit ADR-030）
│   ├── css/
│   │   └── template.css
│   └── html/
│       └── template.html
├── references/                       # プラグイン共通リソース
│   └── scripts/                      # プラグイン単位 venv + 業務スクリプト（ADR-024 / ADR-025）
│       ├── setup/                    # 統合 venv 構築（4 スキル分の依存をマージ）
│       │   ├── requirements.txt
│       │   ├── setup_venv.ps1
│       │   └── teardown_venv.ps1
│       ├── convert-html/
│       │   └── convert.py
│       ├── convert-pdf/
│       │   └── convert_pdf.py
│       ├── convert-pptx/
│       │   └── convert_pptx.py
│       └── convert-from-pptx/
│           └── convert_from_pptx.py
└── skills/
    ├── convert-html/
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── assets/                   # convert-html 固有 assets（extension-toolkit ADR-030）
    │   │   └── js/
    │   ├── evals/                    # 動作分岐の期待挙動ケース
    │   └── references/
    ├── convert-pdf/
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── evals/
    │   └── references/
    ├── convert-pptx/
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── evals/
    │   └── references/
    └── convert-from-pptx/                # PPTX → Markdown 取り込みスキル
        ├── SKILL.md
        ├── README.md
        ├── evals/
        └── references/
```

## 設計上の決定（ADR）

### ADR-001: プラグイン直下／スキル直下 `assets/` の採用

| 項目 | 内容 |
|------|------|
| 状態 | Accepted（extension-toolkit ADR-030 に統合・正規化済み）|
| 決定 | プラグイン直下 `assets/` に HTML/PDF 共通の CSS / HTML テンプレートを格納し、スキル直下 `assets/` でスキル固有のリソース（JS 等）を保持する。同名ファイルがあればスキル直下が優先 |
| 文脈 | `convert-html` と `convert-pdf` は同一の HTML 表現を共有するため CSS / HTML テンプレートを 2 箇所で重複保持すると DRY 違反になる。一方で `convert-html` 固有の対話 JS（`lightbox.js` 等）はプラグイン共通には属さない |
| 上流 SSOT | [extension-toolkit ADR-030](../extension-toolkit/references/architecture-decisions.md)（プラグイン直下・スキル直下 `assets/` の許可リスト追加）|
| 代替案 | 各スキルに完全コピー（重複・同期保守コスト高）/ `references/template/` への配置（実行時参照と語義不一致） |
| トレードオフ | プラグイン直下・スキル直下のトップレベルディレクトリが増えるが、共通リソースの SSOT 化と固有上書きの両立を優先 |

### ADR-002: convert-pdf が convert-html へ subprocess 越しに依存

| 項目 | 内容 |
|------|------|
| 状態 | Accepted |
| 決定 | `convert-pdf` は `convert-html` の `convert.py` を subprocess で呼び出し、HTML 生成ロジックを SSOT に保つ |
| 文脈 | HTML 生成ロジックを HTML / PDF で重複実装すると、デザイン更新時に両方修正が必要になる |
| 解決順序 | `$CONVERT_HTML_SCRIPT` → `$CLAUDE_PLUGIN_ROOT/references/scripts/convert-html/convert.py` → 同一プラグイン内の `__file__.parent.parent/convert-html/convert.py`（`convert_pdf.py:locate_convert_html_script`）|
| 代替案 | convert-html をライブラリ化して import / Skill ツール経由（subprocess 内では呼べない） |
| トレードオフ | プロセス起動オーバーヘッドが発生するが、依存方向の単純さを優先する |

### ADR-003: venv 構築/撤去スクリプトをプラグイン直下に統合

| 項目 | 内容 |
|------|------|
| 状態 | Accepted（extension-toolkit ADR-024 に準拠）|
| 決定 | `plugins/convert-doc/references/scripts/setup/{setup_venv.ps1, teardown_venv.ps1, requirements.txt}` をプラグイン共通として 1 箇所に集約。requirements.txt は全 4 スキル分の依存をマージし、venv は `<work_dir>/.venv` にプラグイン単位で 1 つ作成して全スキルで共有 |
| 文脈 | スキル単位 venv は同一プラグイン内で重複構築されコストが大きい。`environment-setup-toolkit` への委譲は extension-toolkit 環境に依存するが、本プラグインは ADR-024 のプラグイン単位 venv 採用で簡便性と単体配布性を両立する |
| 上流 SSOT | [extension-toolkit ADR-024](../extension-toolkit/references/architecture-decisions.md)（プラグイン単位 venv と `references/scripts/setup/` 配置）|
| 代替案 | スキルごとに個別 venv（ADR-024 違反・廃止）/ `environment-setup-toolkit` への委譲（外部依存増加）|
| トレードオフ | venv が肥大化するが、複数スキル並行利用時の再構築コスト削減を優先する |

## 依存システム（External Dependencies）

本プラグインの 4 スキルのうち、出力系 3 スキルは変換処理のために以下の外部サービスへアクセスする。`convert-from-pptx` は外部依存なしで動作する。

| 依存先 | 用途 | 影響するスキル | オフライン時の挙動 |
|-------|------|-------------|------------------|
| `https://mermaid.ink/svg/{base64url}` | mermaid を SVG に変換（HTML / PDF 用） | convert-html, convert-pdf | 3 回リトライ後 `<div class="mermaid-error">` を出力（コードはエスケープされたまま表示） |
| `https://mermaid.ink/img/{base64url}?type=png` | mermaid を PNG に変換（PPTX 用） | convert-pptx | mermaid 図はテキストコードブロックとしてフォールバック |
| `https://fonts.googleapis.com/css2?family=Lato` | 本文フォントの読み込み（HTML / PDF 用） | convert-html, convert-pdf | システムフォント（ヒラギノ角ゴ Pro W3 等）にフォールバック |

- mermaid.ink のエンドポイントは各スクリプト内で定数として定義しているため、オフライン環境向けに差し替え可能。
- convert-pdf は初回実行時に Playwright が Chromium をダウンロードする（~120MB）。
- convert-from-pptx は外部 API を呼び出さない。SmartArt / 図形フロー → Mermaid 変換も python-pptx + lxml のみで完結する。

## カスタマイズ

- HTML / PDF のデザイン変更（共通）: `${CLAUDE_PLUGIN_ROOT}/assets/css/template.css` を編集するか、同ディレクトリに追加の `.css` ファイルを置く（2 ファイル以上ある場合はスキル実行時に選択プロンプトが表示される）
- convert-html / convert-pdf だけで上書きしたい場合: `skills/{skill-name}/assets/css/` に同名ファイルを置く（スキル側がプラグイン共通を上書きする）
- PPTX の色・フォント・レイアウト変更: `${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-pptx/convert_pptx.py` 冒頭の定数を編集
- PPTX → Markdown の取り込みカスタマイズ: `${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-from-pptx/convert_from_pptx.py` 冒頭の `MONOSPACE_FONTS` / `ALLOWED_IMAGE_EXTS` 等の定数を編集
- Python 依存パッケージの更新: `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/requirements.txt`（プラグイン統合）を編集

## ライセンス

[MIT License](LICENSE) の下で配布されています。
