# HTML レビュー観点プロファイル — security details

`html.md`（hub）から分離した観点本文。hub の 3.x スタブから該当観点が参照する。
共通前提（節1 識別・節2 準拠規約）・節4 重要度表・節5 FW・節6 動的検証コマンドは `html.md`（hub）に残置。
本ファイルは観点 3.4 3.7 を収録。

### 3.4 セキュリティ【担当: web-designer / security-engineer】

- [ ] インラインイベントハンドラ（`onclick` / `onload` 等）へ動的値を埋め込んでいないか（XSS。イベントは外部 JS の `addEventListener` へ分離）
- [ ] `target="_blank"` のリンクに `rel="noopener"`（必要に応じて `noreferrer`）があるか（reverse tabnabbing）
- [ ] 外部 CDN の `<script>` / `<link>` に SRI（`integrity` + `crossorigin`）が付いているか
- [ ] `http://` リソースの読み込みがないか（mixed content。明示的に `https://` を使う）
- [ ] `<iframe>` に `sandbox` / `referrerpolicy` 等の制限があるか、`srcdoc` に未エスケープ値を渡していないか
- [ ] `href="javascript:..."` や `data:` URI へ信頼できない値を埋め込んでいないか
- [ ] フォームの `action` が意図した同一オリジン / 信頼先か・機微情報を `method="get"`（URL 露出）で送信していないか
- [ ] CSP（`<meta http-equiv="Content-Security-Policy">` またはヘッダ）と矛盾するインラインスクリプト / スタイルへの依存が増えていないか

### 3.7 テンプレートエンジン（Liquid / DotLiquid / Razor / Blade / Jinja2 等）【担当: web-designer / security-engineer】

> 本観点は FW プロファイル（`../frameworks/php-web.md` の Blade / Twig、`dotnet.md` の Razor 等）と **意図的に重複カバー** する（XSS はクリティカル経路のため、FW プロファイル未適用時にも本ファイルが安全網として機能する設計）。セクション 1 の「対象外」宣言はマークアップ構造の主管を示すもので、エスケープ安全性の観点は本セクションが横断的に扱う。

- [ ] エスケープ迂回に信頼できない値を渡していないか: Liquid / DotLiquid の生出力、Razor `Html.Raw()` / `@Html.Raw`、Blade `{!! !!}`、Jinja2 `| safe`、ERB `raw` / `<%== %>`（XSS）
- [ ] 既定の自動エスケープ（`{{ }}` / `@` 記法）を無効化していないか、生出力の対象が本当に安全と保証できる値に限定されているか
- [ ] 属性値 / `href` / `src` / インラインイベント / `<script>` 内へのテンプレート変数展開に**文脈別**エスケープが効いているか（HTML エスケープだけでは JS / URL 文脈は防げない）
- [ ] テンプレート内ロジックの肥大化（多重ネストの条件分岐・DB アクセスや重い計算の直接呼び出し）。表示ロジックへ委譲されているか
- [ ] 部分テンプレート / インクルードへ未検証のユーザー入力をパス指定していないか（テンプレートインジェクション・パストラバーサル）
- [ ] ループ内での重い処理・N+1 誘発（コレクション反復中の遅延ロード）がないか

