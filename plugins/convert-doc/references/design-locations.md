# デザインアセット配置規約（convert-doc 共通）

convert-doc プラグインのデザインアセット（HTML 用 CSS / HTML テンプレート / PPTX テーマ JSON）の
配置場所・探索順序・配置先決定ルールを定義する共通規約。
`convert-html` / `convert-pdf` / `convert-pptx`（利用側）と
`add-design-html` / `add-design-pptx`（作成側）の全スキルがこの規約に従う。

## 1. デザインの単位

| 対象 | デザイン 1 件の実体 | 適用方法 |
|------|-------------------|---------|
| HTML / PDF | `<design-name>.css`（+ 任意で同名 `<design-name>.html`） | `convert.py --css-template <絶対パス>`（HTML ペアがあれば `--html-template` も指定） |
| PPTX | `<design-name>.json`（テーマ JSON） | `convert_pptx.py --theme <絶対パス>` |

- HTML 構造は原則デフォルト共通（`assets/html/template.html`）とし、CSS のみで表現する
- CSS だけで表現できないデザインに限り、同名 `.html` をペアで持てる（JS 契約の検証必須）

## 2. 配置場所と探索順序

変換スキルはデザイン列挙時に以下を **上から順に走査し、和集合** を取る。
同名ファイルは先に見つかった側（上の行）を優先する。

| 順序 | 場所 | 用途 |
|-----|------|------|
| 1 | `${CLAUDE_SKILL_DIR}/assets/{css,html,pptx-themes}/` | スキル固有の上書き |
| 2 | `${CLAUDE_PLUGIN_ROOT}/assets/{css,html,pptx-themes}/` | プラグイン同梱（配布物） |
| 3 | ローカルデザインディレクトリ（節 3） | 利用者環境で追加したデザイン |

- PPTX の「デフォルトデザイン」はテーマファイルとしては存在しない（`convert_pptx.py` 内蔵値が SSOT）。
  選択肢には常に「デフォルト」を先頭に含める
- HTML / PDF のデフォルトデザインは `${CLAUDE_PLUGIN_ROOT}/assets/css/template.css`
- 補足（機構差）: 本表は **スキル（エージェント）がデザインを列挙する際の走査順**。
  HTML / PDF では `convert.py` 内部にも既定テンプレート用の解決（skill → plugin の 2 段、
  `--css-template` / `--html-template` 省略時のみ使用）が別途あり、ローカルデザインは
  明示指定でのみ使われる。PPTX にはランタイム解決は無く、列挙 → `--theme` 明示指定のみ
- 補足（既定ブランド色）: デフォルトデザインのネイビー `#003879` は HTML 側
  （`template.css`）と PPTX 側（`Theme` dataclass）に **独立して定義** されている。
  片方を変更する場合はもう片方も併せて更新すること（クロスフォーマットの自動同期は無い）

## 3. ローカルデザインディレクトリ（利用者環境）

プラグインキャッシュ（`${CLAUDE_PLUGIN_ROOT}`）への書き込みはプラグイン更新で消えるため、
利用者環境で追加するデザインは以下に配置する（`local-data-directory.md` の plugins カテゴリ準拠）。

| 優先順位 | 条件 | パス |
|---------|------|------|
| 1 | カレントディレクトリまたは祖先に `.git` が存在 | `<repo_root>/.claude/.local/plugins/convert-doc/designs/` |
| 2 | リポジトリ外での作業 | `~/.claude/.local/plugins/convert-doc/designs/` |

```
.claude/.local/plugins/convert-doc/designs/
├── css/                 # HTML 用デザイン CSS
│   └── <design-name>.css
├── html/                # HTML 構造ペア（任意・同名 CSS とペア）
│   └── <design-name>.html
└── pptx-themes/         # PPTX テーマ JSON
    └── <design-name>.json
```

## 4. 配置先の決定（add-design 系スキル実行時）

新デザインの保存先は実行環境で自動判定する。

| 判定 | 条件 | 配置先 |
|------|------|--------|
| 開発モード | カレントリポジトリ内に `plugins/convert-doc/.claude-plugin/plugin.json` が存在する（= convert-doc のソースリポジトリで作業中） | `<repo_root>/plugins/convert-doc/assets/{css,html,pptx-themes}/`（配布物として追加） |
| 利用者モード | 上記以外 | 節 3 のローカルデザインディレクトリ |

- 判定結果と配置先はユーザーに提示し、`AskUserQuestion` で確認してから書き込む
- 既存の同名ファイルがある場合は無確認で上書きしない（別名提案 or 上書き確認）

## 5. 命名規則

- デザイン名は kebab-case（例: `dark-console`, `warm-paper`）
- 予約名（使用禁止）: `template`（デフォルト CSS / HTML の名前）、`default`（PPTX 内蔵デフォルトの表示名）
- HTML ペアは CSS と完全同名（拡張子のみ相違）: `dark-console.css` + `dark-console.html`

## 6. 検証（配置前必須）

| 対象 | 検証スクリプト | 内容 |
|------|--------------|------|
| CSS | `${CLAUDE_PLUGIN_ROOT}/references/scripts/add-design-html/validate_css.py` | 必須セレクタ契約 + JS 契約（DOM ID・状態クラス・ブレークポイント）+ print 対応 |
| HTML ペア | `${CLAUDE_PLUGIN_ROOT}/references/scripts/add-design-html/validate_html.py` | プレースホルダ完全性 + 必須 DOM 骨格 |
| PPTX テーマ | `${CLAUDE_PLUGIN_ROOT}/references/scripts/add-design-pptx/validate_theme.py` | `convert_pptx.py` の load_theme によるスキーマ・色形式検証 |

検証 FAIL のデザインを配置してはならない。
プラグイン同梱のサンプルデザイン（`assets/` 配下）を変更した場合も、同じ検証スクリプトを通してから配置すること。
