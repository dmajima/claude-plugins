# PHP レビュー観点プロファイル

PHP コードの変更差分をレビューする際の言語固有観点。プロジェクト独自規約が存在する場合はそちらを優先する（`${CLAUDE_PLUGIN_ROOT}/references/conventions-resolution.md` の優先順位に従う）。

## 1. 識別

| 項目 | 値 |
|------|-----|
| 対象拡張子 | `.php`（テンプレート系: `.phtml`） |
| マーカーファイル | `composer.json` / `composer.lock` / `.php-cs-fixer.php` / `phpcs.xml` / `phpstan.neon` / `psalm.xml` |
| 世代判別 | `composer.json` の `require.php`（`^8.1` 等）で PHP 8 系新構文（enum・match・readonly・nullsafe・コンストラクタプロモーション）の可否を判定。宣言が無ければ既存コードの構文から推定 |

## 2. 準拠規約（プロジェクト規約が無い場合のデフォルト基準）

- PSR-1: Basic Coding Standard（PHP-FIG）
- PSR-12: Extended Coding Style Guide（PHP-FIG）
- PER Coding Style（PSR-12 の後継。PHP 8 系新構文のスタイルも規定。新規は PER 優先）
- PSR-4: Autoloader（名前空間とディレクトリ構造の対応）

> PSR-12 は PER Coding Style へ引き継がれており、既存プロジェクトの設定ファイル（`.php-cs-fixer.php` / `phpcs.xml` 等）があればそれを最優先する。

## 3. レビュー観点

### 3.1 正確性・堅牢性【担当: implementation-engineer】

- [ ] 緩い比較 `==` / `!=` による type juggling（`0 == "a"` は PHP 8 未満で true、`"1e3" == "1000"`、`"0" == false`、`null == 0` 等）→ 厳密比較 `===` / `!==` を使用しているか
- [ ] `switch` は緩い比較（`==`）で分岐する。厳密比較・網羅性が必要な箇所で `match`（`===`・網羅漏れで例外）に置換すべきでないか
- [ ] `empty()` / `isset()` の意味の取り違え（`empty("0")` / `empty(0)` は true、`isset()` は null を未定義扱い）
- [ ] 未定義配列キーアクセス（`$arr['x']`）で警告・null 化していないか → `isset()` / `array_key_exists()` / `$arr['x'] ?? $default`
- [ ] 金額・通貨計算に浮動小数点（`float`）を使用していないか（`0.1 + 0.2 !== 0.3`）→ 整数最小単位 / `bcmath` / `GMP`
- [ ] 配列のコピーオンライト・参照（`&`）の取り違えによる意図しない変更がないか
- [ ] 文字列と数値の混在演算・暗黙キャスト（`"10 apples" + 5`、`intdiv()` を使わない整数除算の float 化）に依存していないか
- [ ] 日時処理でタイムゾーン考慮漏れ・可変 `DateTime` の共有（`DateTimeImmutable` を優先）がないか

### 3.2 エラー処理・silent-failure【担当: implementation-engineer】

- [ ] **エラー抑制演算子 `@`**（`@file_get_contents()` 等）でエラー・警告を握りつぶしていないか
- [ ] **空の catch ブロック**（`catch (\Throwable $e) {}` で何もしない）— 例外の握りつぶし
- [ ] `error_reporting(0)` / `ini_set('display_errors', '0')` によるエラー報告の広域抑制
- [ ] catch して**ログのみ出力し、呼び出し元へ異常を伝えない**まま正常フローを継続していないか
- [ ] `catch (\Throwable)` / `catch (\Exception)` の広すぎる捕捉（特定例外型で捕捉すべき箇所）
- [ ] **false / null を返す組み込み関数の戻り値チェック漏れ**（`file_get_contents` / `json_decode` / `preg_match` / `fopen` 等は失敗時 false）
- [ ] `set_error_handler` / `set_exception_handler` を設定した箇所で、警告・エラーを例外化せず無言で捨てていないか
- [ ] 例外の代わりに `false` / `null` / マジック値を返して失敗を隠蔽していないか

### 3.3 型・null 安全【担当: implementation-engineer】

- [ ] **`declare(strict_types=1);` の宣言漏れ**（暗黙の型変換が有効なまま。ファイル先頭の最初の文として宣言）
- [ ] 引数型・戻り値型（PHP 7.0+）・プロパティ型（PHP 7.4+）の**型宣言欠落**
- [ ] null を返しうる関数の戻り値型が `?T` として明示されているか（暗黙 null 返却）
- [ ] null 合体 `??` / null 合体代入 `??=` / nullsafe 演算子 `?->` の適切な使用（手動の重複 null チェックの置換余地・逆に異常の握り潰しになっていないか）
- [ ] `mixed` 型の濫用・Union 型（`int|string`）で表現すべき箇所を `mixed` で回避していないか
- [ ] プリミティブ執着（primitive obsession）: ドメイン概念（メールアドレス・金額等）が `string` / `int` のまま引き回されていないか
- [ ] コレクション・イテレータの要素型が PHPDoc（`@param list<Order>` / `@return array<int, User>`）で表現され、静的解析が効く状態か
- [ ] 不変性: 値オブジェクト・DTO に `readonly`（PHP 8.1）/ `enum`（PHP 8.1）が活用されているか

### 3.4 実行モデル・状態管理【担当: implementation-engineer / performance-reviewer】

- [ ] スーパーグローバル（`$_GET` / `$_POST` / `$_REQUEST` / `$_SESSION`）を業務ロジック層で直接参照していないか（入力は境界で検証・DTO 化し、内部へは値で渡す）
- [ ] `global` キーワード・関数内 `static` 変数による暗黙のグローバル状態に依存していないか
- [ ] 静的プロパティ・シングルトンにリクエスト固有データを保持していないか（FPM は 1 リクエスト 1 プロセスだが、Swoole / RoadRunner 等の常駐 worker ではプロセス跨ぎで状態が汚染される）
- [ ] 参照渡し（`&$var`）の乱用で呼び出し元の状態を意図せず変更していないか
- [ ] ライブラリ・サービス層で `exit` / `die` / `header()` を呼び、処理中断・出力と業務ロジックを混在させていないか（境界層に限定すべき）
- [ ] 1 ファイル = 「シンボル宣言」か「副作用（出力・`ini_set` 等）」のどちらか一方に限定されているか（PSR-1）
- [ ] セッション・グローバル状態の変更が副作用として隠れていないか

### 3.5 命名・スタイル【担当: implementation-engineer / linter-static-analysis】

- [ ] 命名規則: クラス/インターフェース/トレイト/enum = PascalCase（StudlyCaps）、メソッド = camelCase、クラス定数 = UPPER_SNAKE_CASE、プロパティ = プロジェクト内で一貫（PSR-1 は未規定のため既存の多数派に合わせる）
- [ ] インデントはスペース 4（**タブ禁止**）、行長ソフトリミット 120 文字
- [ ] 波括弧位置: **クラス・メソッド・関数の `{` は宣言の次行**、**制御構造（`if` / `for` / `foreach` 等）の `{` はキーワードと同じ行**
- [ ] 短縮タグ（`<?` / `<%` 等）の使用（出力用 `<?=` のみ可）、PHP のみのファイルで終了タグ `?>` を残していないか
- [ ] すべてのプロパティ・メソッドに可視性（`public` / `protected` / `private`）が明示されているか（`abstract` / `final` は可視性の前、`static` は後）
- [ ] 予約語・`true` / `false` / `null` の小文字、`use` インポートの整理（1 文 1 `use`）
- [ ] PSR-4 整合: 名前空間 → ディレクトリ、クラス名 → ファイル名が**大文字小文字まで一致**しているか（`composer.json` の `autoload.psr-4`）

### 3.6 パフォーマンス【担当: performance-reviewer】

- [ ] ループ内での DB 呼び出し（N+1。Eloquent / Doctrine は frameworks/orm.md 参照）
- [ ] 大量データの配列全件メモリ展開（`fetchAll` / 全件 `SELECT`）→ ジェネレータ（`yield`）・カーソル・ページングの検討
- [ ] ループ条件での `count()` / `sizeof()` の毎回再評価、ループ内での重い関数呼び出し
- [ ] ループ内での文字列連結（大量時は配列 + `implode()` を検討）
- [ ] ループ内での `in_array()` の線形探索（キー化 + `isset()` 化の検討）・正規表現の毎回実行
- [ ] 不要な配列コピー（大配列の値渡し）、ループ内での `array_merge` 多用
- [ ] オートロード最適化漏れ（本番は `composer dump-autoload -o` / classmap）、リクエスト毎に走る重い初期化処理

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

### 3.8 コメント・ドキュメント整合【担当: implementation-engineer】

- [ ] PHPDoc（`@param` / `@return` / `@throws` / `@var`）とシグネチャ・実装の不一致（引数名・型・例外）
- [ ] PHPDoc の型記述（`@param array<string, int>` 等）と実際の型宣言・実挙動の乖離
- [ ] コメントの記述とコードの実挙動の乖離（変更差分でコードだけ変わりコメントが古いまま）
- [ ] `@deprecated` / `@internal` タグとコード実態の不整合、型エイリアス（`@phpstan-type` / `@template`）の陳腐化
- [ ] コメントアウトされたコードの残留

## 4. 典型的な指摘パターン（重要度の目安）

| パターン | 重要度の目安 | 根拠 |
|---------|------------|------|
| SQL 文字列連結（ユーザー入力含む） | Critical | SQL インジェクション |
| パスワードの `md5` / `sha1` / 平文保存 | Critical | 認証情報の危殆化 |
| `unserialize()` への信頼できない入力 | Critical | PHP Object Injection・RCE |
| `eval()` / コマンド実行への未検証入力 | Critical | 任意コード・コマンド実行 |
| `echo` への未エスケープ出力 | High〜Critical | XSS |
| `include` / `require` へのユーザー入力 | High〜Critical | LFI / RFI |
| エラー抑制演算子 `@`・空 catch による握りつぶし | High | 障害の無言化・調査不能化 |
| false 戻り値のチェック漏れ（`file_get_contents` 等） | High〜Medium | 異常の伝播漏れ |
| 緩い比較 `==` による type juggling（認証・分岐） | High〜Medium | ロジック誤り・認証バイパス |
| オープンリダイレクト・ヘッダ / メールインジェクション | High〜Medium | フィッシング・レスポンス分割 |
| `declare(strict_types=1)` 欠落・型宣言欠落 | Medium | 暗黙変換によるバグ・保守性低下 |
| ループ内 DB 呼び出し（N+1） | Medium〜High | 性能劣化（データ量依存） |
| 未定義配列キー・null アクセス | Medium | 警告・実行時エラー |
| PSR-12 / PER スタイル違反・命名規則違反 | Medium〜Low | 可読性・規約整合 |
| モダンイディオム未使用（enum・match・readonly 等） | Low | 任意改善（既存スタイルとの整合を優先） |

### NG / OK 例（silent-failure）

```php
// NG: @ でエラーを抑制し、false 戻り値も無視して失敗を隠蔽
public function loadConfig(string $path): array
{
    $json = @file_get_contents($path);      // 失敗しても警告が出ず false になる
    return json_decode($json, true) ?? [];  // 異常が空配列に化け、無言で消える
}

// OK: 失敗を検知し、文脈を付与して例外化する
public function loadConfig(string $path): array
{
    $json = file_get_contents($path);
    if ($json === false) {
        throw new ConfigLoadException("設定ファイル {$path} の読み込みに失敗");
    }

    return json_decode($json, true, flags: JSON_THROW_ON_ERROR);
}
```

## 5. フレームワーク観点

差分に以下の FW が関与する場合、該当プロファイルを併読する:

| 検出条件 | プロファイル |
|---------|-------------|
| `laravel/framework` / `illuminate/*` / `symfony/*` / WordPress（`wp-load.php` / `wp-content/` / `functions.php`） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/php-web.md` |
| Eloquent / Doctrine ORM（ORM 横断観点） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/orm.md` |

## 6. 動的検証コマンド【担当: linter-static-analysis / test-runner】

対応する Bash 権限が許可されている場合のみ実行（なければ SKIPPED 記録）:

| 検証 | コマンド | 判定 |
|------|---------|------|
| 構文チェック | `php -l <file>` | Parse error = 強制 FAIL（Critical） |
| 依存定義検証 | `composer validate` | エラー = Medium〜High |
| フォーマット | `./vendor/bin/php-cs-fixer fix --dry-run --diff` | 差分あり = Medium |
| コーディング規約 | `./vendor/bin/phpcs` | 警告内容に応じて Medium〜Low |
| 静的解析 | `./vendor/bin/phpstan analyse`（/ `psalm`） | エラー = High〜Medium |
| 依存の脆弱性監査 | `composer audit` | 既知脆弱性検出 = High〜Critical |
| テスト | `./vendor/bin/phpunit` | 失敗 1 件ごとに最低 High |
