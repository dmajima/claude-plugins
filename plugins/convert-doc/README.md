# convert-doc

Markdown と **HTML / PDF / PowerPoint（PPTX）** を相互変換できる、6 スキル + 7 コマンド同梱の配布用プラグイン。PPTX → Markdown の取り込み変換、および出力デザインの追加（HTML 用 CSS / PPTX 用テーマ）にも対応する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は各スキルの `SKILL.md` および `references/` 配下を参照してください。

## 提供スキル

| スキル | 役割 | 代表的なトリガーフレーズ |
|-------|------|-----------------------|
| `convert-html` | Markdown → 自己完結型 HTML | 「MD を HTML に変換」「資料を HTML で出力」 |
| `convert-pdf` | Markdown → PDF（内部で HTML 経由） | 「MD を PDF に変換」「資料を PDF で出力」 |
| `convert-pptx` | Markdown → PowerPoint スライド | 「MD を PowerPoint に変換」「設計書をスライドにして」 |
| `convert-from-pptx` | PowerPoint (PPTX) → Markdown 取り込み | 「PPTX を Markdown に変換」「スライドを読める形にして」 |
| `add-design-html` | HTML / PDF 用の新デザイン CSS を作成・検証・配置 | 「HTML のデザインを追加」「ドキュメントの新しいテーマを作って」 |
| `add-design-pptx` | PPTX 用の新デザインテーマ（JSON）を作成・検証・配置 | 「PPTX のテーマを追加」「スライドの配色テーマを作って」 |

出力系の 3 スキル（HTML / PDF / PPTX）は既定で共通のデザイントーン（ネイビー #003879 基調）で出力する。デザインは追加可能で、HTML / PDF は CSS ファイル単位、PPTX はテーマ JSON 単位で切り替えられる（HTML 構造・変換処理・JS 機能は全デザイン共通のため、デザインを増やしても動作は変わらない）。取り込みスキル（`convert-from-pptx`）は構造を Markdown に転記し、フロー図や SmartArt は Mermaid に変換する。

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

全スキル（6 スキル）とも Python 仮想環境を利用します。スキル初回起動時に `references/scripts/setup/setup_venv.sh` が自動実行され、以下の依存パッケージがインストールされます。

| スキル | 主要パッケージ | 追加ダウンロード |
|-------|--------------|----------------|
| convert-html | markdown / Pygments / rcssmin / rjsmin / Pillow | なし |
| convert-pdf | playwright / markdown / Pygments / rcssmin / rjsmin / Pillow | Chromium バイナリ（~120MB、初回のみ） |
| convert-pptx | python-pptx / Pillow / requests / Pygments | なし |
| convert-from-pptx | python-pptx / Pillow / lxml | なし（オフラインで動作） |
| add-design-html | convert-html と同一（サンプル変換で再利用。検証スクリプト自体は標準ライブラリのみ） | なし |
| add-design-pptx | convert-pptx と同一（サンプル変換・テーマ検証で再利用） | なし |

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
| `/convert-pptx` | Markdown → PowerPoint スライド | 16:9・タイトル帯ネイビー（テーマで変更可） |
| `/convert-from-pptx` | PowerPoint (PPTX) → Markdown 取り込み | 画像は別ファイルに抽出、フロー図は Mermaid 化 |
| `/add-design-html` | HTML / PDF 用の新デザイン CSS を追加 | 契約検証（JS 動作保証）付き |
| `/add-design-pptx` | PPTX 用の新デザインテーマを追加 | スキーマ検証 + サンプル変換付き |

利用例:

```
/convert-html ./要件定義.md
/convert-html-full ./要件定義.md ./要件定義.html --title "要件定義書"
/convert-pdf ./設計書.md --format A4 --landscape
/convert-pptx ./提案資料.md --aspect 16:9 --subtitle "2026年4月版"
/convert-from-pptx ./受領資料.pptx ./受領資料.md --include-notes
/add-design-html warm-paper 温かみのある紙っぽいデザイン
/add-design-pptx dark-console ダーク基調のエンジニア向けテーマ
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
- タイトル帯・装飾は既定でネイビーカラーを使用（`--theme` でデザインテーマ切替可、`--dump-default-theme` で既定値を JSON 取得可）

### デザイン追加（`add-design-html` / `add-design-pptx`）

- **HTML / PDF 用**: デフォルト `template.css` をベースに新デザイン CSS を生成。目次トグル・ライトボックス等の JS が依存する DOM ID・状態クラス・ブレークポイントを `validate_css.py` が機械検証するため、デザインを増やしても JS 機能が壊れない。CSS で表現できない構造変更は、JS 契約検証（`validate_html.py`）付きの同名 HTML テンプレートペアとして追加可能
- **PPTX 用**: 色・フォント・サイズ・シンタックス配色に加え、**構図（表紙・本文見出し部のレイアウト構造）** を差し替えるテーマ JSON を生成。構図は `composition` セクションに矩形シェイプ群 + テキスト配置 + コンテンツ開始位置として宣言的に記述でき、スクリプト改修なしで新レイアウト（例: executive 風）を追加できる。`validate_theme.py`（変換スクリプトと同じロードロジック）で検証し、既定構図のリファレンスは `check_default_composition.py` で実装と同期担保
- 配置先は自動判定: convert-doc ソースリポジトリ内なら `plugins/convert-doc/assets/`（配布物化）、利用者環境なら `.claude/.local/plugins/convert-doc/designs/`（プラグイン更新で消えない位置）
- 配置後は `convert-html` / `convert-pdf` / `convert-pptx` 実行時の選択肢に自動的に現れる（規約: `references/design-locations.md`。PDF は `--css-template` パススルーで HTML と同じデザインを適用）
- 同梱サンプルデザイン: `warm-paper`（HTML / PDF 用・温かみのある紙面イメージ）、`dark-console`（PPTX 用・暗色コンソール風コードブロック）

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
│   ├── convert-from-pptx.md
│   ├── add-design-html.md
│   └── add-design-pptx.md
├── assets/                           # プラグイン共通 assets（extension-toolkit ADR-030）
│   ├── css/
│   │   └── template.css              # デフォルトデザイン（追加デザイン CSS もここに並置）
│   ├── html/
│   │   └── template.html             # 共通 HTML テンプレート（デザイン固有ペアも並置可）
│   └── pptx-themes/                  # PPTX 追加テーマ JSON（add-design-pptx が配置）
├── ruff.toml                         # Python スクリプトの静的解析設定（ADR-005）
├── references/                       # プラグイン共通リソース
│   ├── CLAUDE.md                     # references/ 配下の参照原則（エージェント向け）
│   ├── design-locations.md           # デザイン配置・探索規約（SSOT）
│   └── scripts/                      # プラグイン単位 venv + 業務スクリプト（ADR-024 / ADR-025）
│       ├── setup/                    # 統合 venv 構築（全スキル分の依存をマージ）
│       │   ├── requirements.txt
│       │   ├── setup_venv.sh
│       │   └── teardown_venv.sh
│       ├── convert-html/
│       │   └── convert.py
│       ├── convert-pdf/
│       │   └── convert_pdf.py
│       ├── convert-pptx/
│       │   └── convert_pptx.py       # Theme dataclass / composition / --theme / --dump-default-theme
│       ├── convert-from-pptx/
│       │   ├── convert_from_pptx.py
│       │   ├── verify_md.py          # 変換結果の検証
│       │   ├── run_via_job.sh        # Start-Job 経由ラッパー（Windows ハング対策）
│       │   └── run_verify_via_job.sh
│       ├── add-design-html/
│       │   ├── validate_css.py       # デザイン CSS の契約検証
│       │   └── validate_html.py      # HTML ペアの JS 契約検証
│       └── add-design-pptx/
│           ├── validate_theme.py     # テーマ JSON のスキーマ検証
│           └── check_default_composition.py  # 既定構図リファレンスの同期照合
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
    │   └── references/               # theme-selection.md を含む
    ├── convert-from-pptx/                # PPTX → Markdown 取り込みスキル
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── evals/
    │   └── references/
    ├── add-design-html/                  # HTML / PDF 用デザイン追加スキル
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── evals/
    │   └── references/               # css-contract.md を含む
    └── add-design-pptx/                  # PPTX 用デザインテーマ追加スキル
        ├── SKILL.md
        ├── README.md
        ├── evals/
        └── references/               # theme-schema.md を含む
```

## 設計上の決定（ADR）

### ADR-001: プラグイン直下／スキル直下 `assets/` の採用

| 項目 | 内容 |
|------|------|
| 状態 | Accepted（extension-toolkit ADR-030 に統合・正規化済み）|
| 決定 | プラグイン直下 `assets/` に HTML/PDF 共通の CSS / HTML テンプレートを格納し、スキル直下 `assets/` でスキル固有のリソース（JS 等）を保持する。同名ファイルがあればスキル直下が優先 |
| 文脈 | `convert-html` と `convert-pdf` は同一の HTML 表現を共有するため CSS / HTML テンプレートを 2 箇所で重複保持すると DRY 違反になる。一方で `convert-html` 固有の対話 JS（`lightbox.js` 等）はプラグイン共通には属さない |
| 上流 SSOT | [extension-toolkit ADR-030](../extension-toolkit/references/architecture/decisions-021-033.md)（プラグイン直下・スキル直下 `assets/` の許可リスト追加）|
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
| 決定 | `plugins/convert-doc/references/scripts/setup/{setup_venv.sh, teardown_venv.sh, requirements.txt}` をプラグイン共通として 1 箇所に集約。requirements.txt は全スキル分の依存をマージし、venv は `<work_dir>/.venv` にプラグイン単位で 1 つ作成して全スキルで共有 |
| 文脈 | スキル単位 venv は同一プラグイン内で重複構築されコストが大きい。`environment-setup-toolkit` への委譲は extension-toolkit 環境に依存するが、本プラグインは ADR-024 のプラグイン単位 venv 採用で簡便性と単体配布性を両立する |
| 上流 SSOT | [extension-toolkit ADR-024](../extension-toolkit/references/architecture/decisions-021-033.md)（プラグイン単位 venv と `references/scripts/setup/` 配置）|
| 代替案 | スキルごとに個別 venv（ADR-024 違反・廃止）/ `environment-setup-toolkit` への委譲（外部依存増加）|
| トレードオフ | venv が肥大化するが、複数スキル並行利用時の再構築コスト削減を優先する |

### ADR-004: デザインの外部化（CSS 単位 / テーマ JSON 単位）と配置規約

| 項目 | 内容 |
|------|------|
| 状態 | Accepted |
| 決定 | デザインの単位を HTML / PDF は「CSS ファイル（+ 任意の同名 HTML ペア）」、PPTX は「テーマ JSON」とし、変換パイプライン（HTML 構造・convert.py・JS・convert_pptx.py のレンダリング）は全デザイン共通に保つ。PPTX のデフォルト値は `Theme` dataclass のフィールドデフォルトを SSOT とし、テーマファイルとして二重管理しない（`--dump-default-theme` で参照可能）。利用者環境の追加デザインは `.claude/.local/plugins/convert-doc/designs/` に配置する |
| 文脈 | デザインごとに HTML / JS / 変換処理が分岐すると、JS 機能導入のバグやデザイン固有の動作不良が発生しやすい。差し替え面を CSS / テーマ JSON に限定し、JS が依存する DOM 契約を `validate_css.py` / `validate_html.py` で機械検証することで抑制する |
| 上流 SSOT | [`references/design-locations.md`](references/design-locations.md)（配置・探索規約）、[`skills/add-design-html/references/css-contract.md`](skills/add-design-html/references/css-contract.md)（セレクタ契約） |
| 代替案 | テンプレート .pptx 方式（座標直書き構築と相性が悪い）/ デザインごとの HTML 複製（JS 契約の保守が発散）/ プラグインキャッシュへの直接追加（更新で消える） |
| トレードオフ | CSS 1 ファイルが大きくなる（変数化しない）が、デザイン間の独立性と検証可能性を優先する。また、サンプルデザイン（warm-paper / dark-console）を選択スキャン対象の `assets/` に同梱するため、**クリーンインストールでも対話モードの変換で常にデザイン選択 UI が表示される**（「1 件なら無プロンプト」分岐はサンプルを除去したカスタム構成でのみ成立）。デザイン機能の発見性を優先した意図的な選択であり、選択 UI を出したくない場合は非対話経路（`Skill(...)` 呼び出し・`/convert-html-full`）を使う |

### ADR-005: プラグイン直下 `ruff.toml` の配置

| 項目 | 内容 |
|------|------|
| 状態 | Accepted |
| 決定 | Python スクリプト（`references/scripts/` 配下）の静的解析設定 `ruff.toml` をプラグイン直下に置く |
| 文脈 | 本プラグインは決定論的な Python 変換スクリプトを中核とするため、コード品質のベースライン（E/F/W/B/UP）を設定ファイルとして固定する。ruff は設定ファイルを対象ファイルの祖先ディレクトリから探索するため、スクリプト群のルートであるプラグイン直下が自然な配置となる |
| 代替案 | リポジトリルートに集約（他プラグインの制約と混ざる）/ 設定なし（レビュー観点が暗黙化する） |
| トレードオフ | プラグイン直下の非標準ファイルが 1 つ増えるが、スクリプト品質基準の明示を優先する |

### ADR-006: デザイン追加スキルのフォーマット別分割（add-design-html / add-design-pptx）

| 項目 | 内容 |
|------|------|
| 状態 | Accepted |
| 決定 | デザイン追加機能を単一スキルではなく、出力フォーマット別の 2 スキル（`add-design-html` / `add-design-pptx`）に分割する |
| 文脈 | デザインの単位（CSS ファイル vs テーマ JSON）・検証内容（セレクタ / JS 契約 vs スキーマ）・サンプル変換の依存（markdown 系 vs python-pptx）がフォーマット間で完全に異なり、単一スキルにすると SKILL.md の分岐が肥大化しトリガー判定も曖昧になる |
| 代替案 | 統合単一スキル `add-design`（分岐肥大・責務不明瞭）/ convert-* 各スキルへの内包（変換と作成の責務混在） |
| トレードオフ | スキル数が増えるが、単一責務・独立した契約検証・明確なトリガー分離を優先する |

### ADR-007: PPTX 構図（composition）の宣言的スキーマ化

| 項目 | 内容 |
|------|------|
| 状態 | Accepted |
| 決定 | 表紙・本文見出し部のレイアウト構造をテーマ JSON の `composition` セクション（矩形 `shapes[]` + 固定テキストスロット + `content_top`）として宣言的に定義可能にし、`convert_pptx.py` の描画は構図データ駆動とする。既定構図の SSOT は `build_default_composition()`（theme-schema.md のリファレンスは `check_default_composition.py` で機械照合）。色トークンは load 時に解決せず描画時に Theme から遅延解決する（`--primary-color` の適用順との整合のため） |
| 文脈 | ADR-004 の「テーマ JSON = スカラー値の差し替え」の範囲ではレイアウト構造（例: executive 風の表紙・キーメッセージ型見出し）を表現できず、構図の変更のたびに本体スクリプト改修が必要だった |
| 宣言で表現できる範囲 | 装飾矩形 + 既定テキストスロット（cover: title/subtitle、content_header: title）+ `content_top` まで。フッター等の新しい構造要素の追加は本体改修が必要（スロット固定は検証可能性と後方互換を優先した意図的な制約） |
| 代替案 | プリセット enum（新構図のたびに本体改修が必要）/ テンプレート PPTX 流し込み（スライド分割の縦積算制御と相性が悪い） |
| トレードオフ | shapes と `content_top` の位置整合はテーマ作成者責任（theme-schema.md の設計ガイドで補助）。convert_pptx.py は単一ファイル配布のため composition 対応で約 400 行増となった。将来さらに肥大化する機能追加を行う時点で、composition ロジック（dataclass 群・パーサ・描画ヘルパ）の別モジュール分離を検討する |

## 依存システム（External Dependencies）

本プラグインの 6 スキルのうち、出力系 3 スキル（convert-html / convert-pdf / convert-pptx）と、サンプル変換でそれらを再利用する add-design 系 2 スキルは、変換処理のために以下の外部サービスへアクセスする。`convert-from-pptx` は外部依存なしで動作する。

| 依存先 | 用途 | 影響するスキル | オフライン時の挙動 |
|-------|------|-------------|------------------|
| `https://mermaid.ink/svg/{base64url}` | mermaid を SVG に変換（HTML / PDF 用） | convert-html, convert-pdf | 3 回リトライ後 `<div class="mermaid-error">` を出力（コードはエスケープされたまま表示） |
| `https://mermaid.ink/img/{base64url}?type=png` | mermaid を PNG に変換（PPTX 用） | convert-pptx | mermaid 図はテキストコードブロックとしてフォールバック |
| `https://fonts.googleapis.com/css2?family=Lato` | 本文フォントの読み込み（HTML / PDF 用） | convert-html, convert-pdf | システムフォント（ヒラギノ角ゴ Pro W3 等）にフォールバック |

- mermaid.ink のエンドポイントは各スクリプト内で定数として定義しているため、オフライン環境向けに差し替え可能。
- convert-pdf は初回実行時に Playwright が Chromium をダウンロードする（~120MB）。
- convert-from-pptx は外部 API を呼び出さない。SmartArt / 図形フロー → Mermaid 変換も python-pptx + lxml のみで完結する。

## カスタマイズ

- **HTML / PDF の新デザイン追加（推奨）**: `add-design-html` スキル（`/add-design-html`）を使う。契約検証付きで CSS（必要時 HTML ペア）を生成・配置し、複数デザインは変換時の選択プロンプトに自動で現れる
- **PPTX の新デザイン追加（推奨）**: `add-design-pptx` スキル（`/add-design-pptx`）を使う。テーマ JSON（色・フォント・サイズ・シンタックス配色・構図）を検証付きで生成・配置する。既定値の一覧は `convert_pptx.py --dump-default-theme` で取得できる（構図は動的追従のため含まれない。既定構図は `skills/add-design-pptx/references/theme-schema.md` を参照）
- デフォルトデザイン自体の変更: `${CLAUDE_PLUGIN_ROOT}/assets/css/template.css`（HTML / PDF）を直接編集する。PPTX の既定値は `convert_pptx.py` の `Theme` dataclass のフィールドデフォルトが SSOT
- convert-html / convert-pdf だけで上書きしたい場合: `skills/<skill-name>/assets/css/` に同名ファイルを置く（スキル側がプラグイン共通を上書きする）
- デザインの配置場所・探索順序の規約: `${CLAUDE_PLUGIN_ROOT}/references/design-locations.md`
- PPTX → Markdown の取り込みカスタマイズ: `${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-from-pptx/convert_from_pptx.py` 冒頭の `MONOSPACE_FONTS` / `ALLOWED_IMAGE_EXTS` 等の定数を編集
- Python 依存パッケージの更新: `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/requirements.txt`（プラグイン統合）を編集

## ライセンス

[MIT License](LICENSE) の下で配布されています。
