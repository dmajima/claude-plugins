# JavaScript レビュー観点プロファイル — security details

`javascript.md`（hub）から分離した観点本文。hub の 3.x スタブから該当観点が参照する。
共通前提（節1 識別・節2 準拠規約）・節4 重要度表・節5 FW・節6 動的検証コマンドは `javascript.md`（hub）に残置。
本ファイルは観点 3.7 を収録。

### 3.7 セキュリティ【担当: security-engineer】

- [ ] **`innerHTML` / `outerHTML` / `document.write` へのユーザー入力代入**（XSS → `textContent` / サニタイズ）
- [ ] **`eval` / `new Function` / 文字列を渡す `setTimeout` / `setInterval`**（コードインジェクション）
- [ ] **プロトタイプ汚染**（信頼できない入力を `Object.assign` / スプレッド / 再帰マージで取り込む際の `__proto__` / `constructor` / `prototype` キー）
- [ ] SQL / NoSQL / OS コマンドの文字列連結（インジェクション → パラメタライズ / エスケープ。node.md 参照）
- [ ] 機密情報（API キー・トークン・接続文字列）のハードコード・ログ出力・クライアントバンドルへの混入
- [ ] 乱数に `Math.random()` を使用（セキュリティ用途は `crypto.getRandomValues` / `crypto.randomUUID`）
- [ ] 正規表現の ReDoS（ユーザー入力に対するカタストロフィックバックトラッキング）
- [ ] `postMessage` の `origin` 未検証・送信側の `targetOrigin` に `"*"` を使用（クロスオリジンリーク）
- [ ] オープンリダイレクト（ユーザー入力の URL を検証せず `location.href` / リダイレクト先に使用）
- [ ] `target="_blank"` のリンクに `rel="noopener noreferrer"` 欠落（リバースタブナビング）

