# HTML レビュー観点プロファイル

HTML およびテンプレート内の素のマークアップの変更差分をレビューする際の言語固有観点。プロジェクト独自規約が存在する場合はそちらを優先する（`${CLAUDE_PLUGIN_ROOT}/references/conventions-resolution.md` の優先順位に従う）。

## 1. 識別

| 項目 | 値 |
|------|-----|
| 対象拡張子 | `.html` / `.htm`（素の HTML）。テンプレート内の素マークアップ部分も対象 |
| マーカーファイル | 単一のマーカーは持たない（拡張子の出現数で検出）。整形設定として `.editorconfig` / `.prettierrc*`、検証設定として `.htmlvalidate.json` が併存しうる |
| 対象外 | `.vue` / `.jsx` / `.tsx` / `.blade.php` / `.twig` / `.erb` 等のテンプレート構文自体は各フレームワークプロファイルで扱う（セクション5）。本プロファイルは静的 HTML とテンプレート内の素マークアップに適用する |

## 2. 準拠規約（プロジェクト規約が無い場合のデフォルト基準）

- Google HTML/CSS Style Guide（大文字小文字の統一・id/class 区切り・セマンティクス・関心の分離）
- WHATWG HTML Living Standard（要素のセマンティクス・妥当な入れ子・ブール属性）
- WCAG 2.2 / WAI-ARIA Authoring Practices Guide（アクセシビリティ）

## 3. レビュー観点

> 3.x 本文は観点別 details に分離済み。**各 3.x の【担当】に対応する details のみ Read** すること（重要度表(節4)・動的検証(節6)は本 hub に残置）:
> - [`html-core.md`](html-core.md) … 3.1 3.2 3.3 3.5 3.6 3.8
> - [`html-security.md`](html-security.md) … 3.4 3.7

### 3.1 セマンティクス・文書構造【担当: web-designer】

> → 本文は [`html-core.md`](html-core.md)（3.1）

### 3.2 アクセシビリティ（WCAG）【担当: web-designer】

> → 本文は [`html-core.md`](html-core.md)（3.2）

### 3.3 フォーム・入力【担当: web-designer】

> → 本文は [`html-core.md`](html-core.md)（3.3）

### 3.4 セキュリティ【担当: web-designer / security-engineer】

> → 本文は [`html-security.md`](html-security.md)（3.4）

### 3.5 命名・スタイル【担当: web-designer / linter-static-analysis】

> → 本文は [`html-core.md`](html-core.md)（3.5）

### 3.6 パフォーマンス【担当: web-designer / performance-reviewer】

> → 本文は [`html-core.md`](html-core.md)（3.6）

### 3.7 テンプレートエンジン（Liquid / DotLiquid / Razor / Blade / Jinja2 等）【担当: web-designer / security-engineer】

> → 本文は [`html-security.md`](html-security.md)（3.7）

### 3.8 コメント・メタ情報整合【担当: web-designer】

> → 本文は [`html-core.md`](html-core.md)（3.8）

## 4. 典型的な指摘パターン（重要度の目安）

| パターン | 重要度の目安 | 根拠 |
|---------|------------|------|
| インラインハンドラ / テンプレート生出力への未エスケープ値埋め込み | Critical | XSS |
| エスケープ迂回（`Html.Raw` / `{!! !!}` / `\| safe` / 生出力）へ信頼できない値 | Critical | XSS |
| `http://` リソース混在（mixed content） | High | 通信改ざん・ブラウザブロック |
| `img` の `alt` 欠落・フォーム `label` 未関連付け | High | アクセシビリティ阻害（操作・読み上げ不能） |
| `<div onclick>` 等でのクリック要素代替 | High〜Medium | キーボード操作・支援技術対応の喪失 |
| `target="_blank"` の `rel="noopener"` 欠落 | High〜Medium | reverse tabnabbing |
| 外部 CDN スクリプトの SRI 欠落 | High〜Medium | サプライチェーン改ざん |
| ARIA 誤用・不要 ARIA | Medium〜High | 支援技術での誤読・操作不能 |
| `id` 重複・不正な入れ子 | Medium | 参照破壊・レンダリング不定 |
| `img` の width/height 欠落（CLS）・lazy 未指定 | Medium | 体感性能の劣化 |
| 非推奨要素・命名 / スタイル規約違反 | Medium〜Low | 保守性・規約整合 |
| ブール属性の冗長記述・実体参照の多用 | Low | 任意改善（既存スタイルとの整合を優先） |

### NG / OK 例（XSS: インラインハンドラ・テンプレート生出力）

```html
<!-- NG: ユーザー入力をインラインハンドラと生出力へ直接展開（XSS） -->
<button onclick="showUser('{{ user_name }}')">表示</button>
<div>{{ comment_html | safe }}</div>

<!-- OK: 挙動は外部 JS の addEventListener で data 属性経由、値は既定の自動エスケープに委ねる -->
<button type="button" class="show-user" data-user="{{ user_name }}">表示</button>
<div>{{ comment_text }}</div>
```

## 5. フレームワーク観点

差分に以下の FW が関与する場合、該当プロファイルを併読する:

| 検出条件 | プロファイル |
|---------|-------------|
| React / Next.js コンポーネント内マークアップ（JSX / TSX） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/react.md` |
| Vue / Nuxt コンポーネント内マークアップ（SFC `.vue`） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/vue.md` |
| スタイル（CSS / インライン `style` / クラス設計）の評価 | `${CLAUDE_PLUGIN_ROOT}/references/languages/css.md` |

## 6. 動的検証コマンド【担当: linter-static-analysis】

対応する Bash 権限が許可されている場合のみ実行（なければ SKIPPED 記録）:

| 検証 | コマンド | 判定 |
|------|---------|------|
| マークアップ検証 | `npx html-validate "**/*.html"` | error = 強制 FAIL（High〜Medium）、warning = Medium〜Low |
| 軽量 Lint | `npx htmlhint "**/*.html"` | error 件数に応じて Medium〜Low |
| 整形 | `npx prettier --check "**/*.html"` | 差分あり = Low〜Medium |
| アクセシビリティ監査（任意） | Lighthouse / axe-core（ブラウザ・CI 実行） | 違反の深刻度に応じて付与 |
