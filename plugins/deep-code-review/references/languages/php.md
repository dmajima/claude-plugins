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

> 3.x 本文は観点別 details に分離済み。**各 3.x の【担当】に対応する details のみ Read** すること（重要度表(節4)・動的検証(節6)は本 hub に残置）:
> - [`php-impl.md`](php-impl.md) … 3.1 3.2 3.3 3.4 3.5 3.6 3.8
> - [`php-security.md`](php-security.md) … 3.7

### 3.1 正確性・堅牢性【担当: implementation-engineer】

> → 本文は [`php-impl.md`](php-impl.md)（3.1）

### 3.2 エラー処理・silent-failure【担当: implementation-engineer】

> → 本文は [`php-impl.md`](php-impl.md)（3.2）

### 3.3 型・null 安全【担当: implementation-engineer】

> → 本文は [`php-impl.md`](php-impl.md)（3.3）

### 3.4 実行モデル・状態管理【担当: implementation-engineer / performance-reviewer】

> → 本文は [`php-impl.md`](php-impl.md)（3.4）

### 3.5 命名・スタイル【担当: implementation-engineer / linter-static-analysis】

> → 本文は [`php-impl.md`](php-impl.md)（3.5）

### 3.6 パフォーマンス【担当: performance-reviewer】

> → 本文は [`php-impl.md`](php-impl.md)（3.6）

### 3.7 セキュリティ【担当: security-engineer】

> → 本文は [`php-security.md`](php-security.md)（3.7）

### 3.8 コメント・ドキュメント整合【担当: implementation-engineer】

> → 本文は [`php-impl.md`](php-impl.md)（3.8）

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
