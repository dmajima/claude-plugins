# PHP レビュー観点プロファイル — security details

`php.md`（hub）から分離した観点本文。hub の 3.x スタブから該当観点が参照する。
共通前提（節1 識別・節2 準拠規約）・節4 重要度表・節5 FW・節6 動的検証コマンドは `php.md`（hub）に残置。
本ファイルは観点 3.7 を収録。

### 3.7 セキュリティ【担当: security-engineer】

> **埋め込み SQL の横断適用**: `$pdo->query(...)` / `mysqli_query` / `$wpdb->query` 等でコードに埋め込まれた SQL 文字列には、インジェクション以外にも `${CLAUDE_PLUGIN_ROOT}/references/languages/sql.md` の観点（`SELECT *`・列非明示・NULL 三値論理・方言固有）を併用適用する（`.sql` ファイルが差分に無くても適用。language-detection.md Step 4）。

- [ ] **SQL 文字列連結**（ユーザー入力を連結したクエリ）→ PDO プリペアドステートメント（`prepare` + バインド）/ ORM
- [ ] **XSS**: `echo` / テンプレートへの未エスケープ出力 → `htmlspecialchars($v, ENT_QUOTES, 'UTF-8')`（FW のテンプレートエスケープ）
- [ ] **パスワード**: `password_hash()` / `password_verify()` を使用しているか（`md5` / `sha1` / 平文保存は Critical）
- [ ] **`unserialize()` への信頼できない入力**（PHP Object Injection）→ `json_decode` / `allowed_classes` 制限
- [ ] ファイルアップロード検証（MIME・拡張子・保存パス・`is_uploaded_file`）の欠落、`include` / `require` へのユーザー入力（LFI / RFI）
- [ ] **`eval()` / `assert()`（文字列）/ `extract()` / 可変変数 `$$var`** へのユーザー入力（コード実行・スコープ汚染）
- [ ] コマンド実行（`exec` / `system` / `shell_exec` / `passthru` / バッククォート）+ 未エスケープ入力 → `escapeshellarg()` / `escapeshellcmd()`
- [ ] スーパーグローバル（`$_GET` / `$_POST`）の未検証使用 → `filter_input()` / `filter_var()` で型・形式を検証
- [ ] 乱数: セキュリティ用途に `rand()` / `mt_rand()` / `uniqid()` を使用していないか → `random_int()` / `random_bytes()`
- [ ] セッション固定化対策（ログイン後の `session_regenerate_id(true)`）・ヘッダ / メールインジェクション（`header()` / `mail()` へのユーザー入力に改行混入）の考慮
- [ ] オープンリダイレクト（`header('Location: ' . $_GET['url'])` 等、検証しないリダイレクト先）
- [ ] 機密情報（DB 認証情報・API キー）のハードコード・ログ出力、CSRF 対策の欠落（FW 機構を利用）

