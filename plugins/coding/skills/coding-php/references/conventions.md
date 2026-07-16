# PHP 言語プロファイル

## 1. 識別（プロジェクト検出）

| 項目 | 値 |
|------|-----|
| 対象拡張子 | `.php`（テンプレート系: `.phtml`） |
| マーカーファイル | `composer.json`（依存・オートロード定義）／ `composer.lock`（プロジェクトルートでの検出対象） |

## 2. デファクトスタンダード規約

**準拠規約**:
- PSR-1: Basic Coding Standard（https://www.php-fig.org/psr/psr-1/）
- PSR-12: Extended Coding Style Guide（https://www.php-fig.org/psr/psr-12/）
- PER Coding Style（PSR-12 の後継。PHP-FIG が PSR-12 を PER へ移行済み: https://www.php-fig.org/per/coding-style/）
- PSR-4: Autoloader（名前空間とディレクトリ構造の対応: https://www.php-fig.org/psr/psr-4/）

> PSR-12 は PER Coding Style に引き継がれており、PER は PHP 8 系の新構文（enum・match・コンストラクタプロモーション等）のスタイルも規定する。新規プロジェクトでは PER を第一に参照し、既存プロジェクトの設定（`.php-cs-fixer.php` 等）があればそれを優先する。

### 2.1 命名規則

出典は PSR-1（https://www.php-fig.org/psr/psr-1/）。PSR-1 が明示的に規定するのは **クラス名・メソッド名・クラス定数** のみである。

| 対象 | 規則 | 例 |
|------|------|-----|
| クラス / インターフェース / トレイト / enum | PascalCase（PSR-1 の呼称は StudlyCaps） | `OrderService`, `UserRepositoryInterface` |
| メソッド | camelCase | `getUserName()`, `findById()` |
| クラス定数 | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT`, `DEFAULT_LOCALE` |
| プロパティ | **PSR では規定なし**（`$camelCase` / `$under_score` のいずれでも可。プロジェクト内で一貫させる） | `$userName` または `$user_name`（統一必須） |
| 変数 | PSR では規定なし（慣習的に camelCase が多いが未規定） | `$orderTotal` |
| 関数（名前空間外のグローバル関数） | PSR では規定なし（PHP 標準関数は snake_case） | `format_currency()` 等 |
| ファイル名 | PSR-4 によりクラス名と完全一致（大文字小文字含む） | `OrderService.php` |

> **プロパティ命名の注意**: PSR-1 は「`$StudlyCaps` / `$camelCase` / `$under_score` のいずれを使うかの推奨を意図的に避ける。採用した規則は妥当なスコープ内で一貫して適用すること」と明記している。したがってプロパティ命名はプロジェクト独自規約に従い、規約が無ければ既存コードの多数派に合わせる。

### 2.2 インデント・フォーマット

出典は PSR-12 / PER Coding Style。

| 項目 | 規定 |
|------|------|
| インデント | スペース 4 個（**タブ禁止**） |
| 行長目安 | ソフトリミット 120 文字（`MUST`）／ 80 文字以下が望ましい（`SHOULD NOT` exceed 80）。ハードリミットは無し |
| 開始タグ | `<?php` 完全タグ（出力用の短縮タグ `<?=` のみ併用可。それ以外の短縮タグは禁止） |
| 終了タグ | PHP のみのファイルでは末尾の `?>` を **省略** する |
| 文字列引用符 | PSR では規定なし（変数展開・エスケープが不要なら単一引用符 `'` を用いる慣習が一般的だが未規定） |
| 文末 | 各文の末尾にセミコロン `;`。1 行につき 1 文 |
| 改行コード / 末尾 | Unix LF。ファイル末尾は非空行を単一の LF で終端する（余分な空行を残さない、PSR-12 2.2）。行末の余分な空白は禁止 |
| キーワード | 予約語および `true` / `false` / `null` はすべて小文字 |

### 2.3 主要スタイル規則

コード生成時に判断へ影響する主要規則を挙げる。

**PSR-1（基本規約）**
- PHP タグは `<?php ?>` または `<?= ?>` のみ使用する
- PHP を含むファイルは UTF-8（BOM なし）で保存する
- 1 ファイルは「シンボルの宣言（クラス・関数・定数）」か「副作用の発生（出力・`ini_set` 等の状態変更）」のどちらか一方に限定する（両方を混在させない）
- 名前空間とクラスはオートローディング規約（PSR-4）に従う

**PSR-12 / PER（拡張スタイル）**
- `declare(strict_types=1);` を使う場合は、`<?php` に続くファイルの最初の文として記述する
- **クラス・メソッド・関数の開き波括弧 `{` は宣言の次の行**に置き、閉じ波括弧 `}` は本体の次の行に置く
- **制御構造（`if` / `for` / `foreach` / `while` / `switch` 等）の開き波括弧 `{` はキーワードと同じ行**に置く。キーワードの後に空白 1 個、開き括弧 `(` の直後と閉じ括弧 `)` の直前に空白を入れない
- `extends` / `implements` はクラス宣言と同じ行に置く（`implements` が複数行に渡る場合の規定は PSR-12 を参照）
- すべてのプロパティ・メソッドに可視性（`public` / `protected` / `private`）を明示する。`abstract` / `final` は可視性の前、`static` は可視性の後に置く
- `use` インポート文は名前空間宣言の後にまとめて置き、1 文 1 `use`

```php
<?php

declare(strict_types=1);

namespace App\Service;

use App\Repository\OrderRepository;

final class OrderService implements OrderServiceInterface
{
    public const int MAX_ITEMS = 100;

    public function __construct(
        private readonly OrderRepository $repository,
    ) {
    }

    public function findById(int $id): ?Order
    {
        if ($id <= 0) {
            return null;
        }

        return $this->repository->find($id);
    }
}
```

**PSR-4 オートロード**
- 完全修飾クラス名 `\Vendor\Namespace\ClassName` を、名前空間プレフィックス → ベースディレクトリ、サブ名前空間 → サブディレクトリ、クラス名 → ファイル名 `ClassName.php` に対応させる
- 対応は `composer.json` の `autoload.psr-4` で宣言する。クラス名とファイル名は大文字小文字まで一致させる

```json
{
  "autoload": {
    "psr-4": { "App\\": "src/" }
  }
}
```

→ `App\Service\OrderService` は `src/Service/OrderService.php` に配置する。マッピング変更後は `composer dump-autoload` を実行する。

## 3. ツールチェーン

| 用途 | コマンド | 備考 |
|------|---------|------|
| 依存管理 / オートロード生成 | `composer install` / `composer require <pkg>` / `composer dump-autoload` | 依存は Composer で一元管理 |
| テスト | `phpunit` / `vendor/bin/phpunit` | PHPUnit（デファクト） |
| 静的解析 | `phpstan analyse` / `psalm` | PHPStan・Psalm（型・バグ検出） |
| Lint（コーディング規約検査） | `phpcs`（PHP_CodeSniffer） | 規約違反の検出 |
| フォーマット（自動整形） | `php-cs-fixer fix`（PHP CS Fixer） / `phpcbf`（PHP_CodeSniffer 付属の自動修正） | PSR-12 / PER 準拠へ整形 |

### プロジェクト規約ファイル（存在時は本プロファイルより優先）

| ファイル | 内容 |
|---------|------|
| `.editorconfig` | インデント・改行・文字コード |
| `.php-cs-fixer.php` / `.php-cs-fixer.dist.php` | PHP CS Fixer のルールセット（フォーマット規約） |
| `phpcs.xml` / `phpcs.xml.dist` | PHP_CodeSniffer の規約定義（適用スタンダード・除外ルール） |
| `phpstan.neon` / `phpstan.neon.dist` | PHPStan の解析レベル・除外設定 |
| `psalm.xml` | Psalm の解析設定 |
| `composer.json` | 依存定義・`autoload`（PSR-4 名前空間 → ディレクトリ）・PHP バージョン制約 |

## 4. イディオム・ベストプラクティス

- **`declare(strict_types=1);` を全ファイル先頭で宣言**し、暗黙の型変換を無効化する（型安全性の向上）
- **型宣言を積極的に付与**する: 引数型・戻り値型（PHP 7.0+）、プロパティ型（PHP 7.4+）、Union 型 `int|string`（PHP 8.0+）
- **null 合体演算子** `??`（未定義・null 時の既定値）と **null 合体代入** `??=` を活用する
- **`match` 式（PHP 8.0）** を用いる（厳密比較 `===`・網羅漏れ時に例外・フォールスルー無し。`switch` より安全）
- **`readonly` プロパティ（PHP 8.1）** で不変オブジェクトを表現する
- **`enum`（PHP 8.1）** で列挙型を定義する（マジック定数の乱用を避ける）
- **コンストラクタプロパティプロモーション（PHP 8.0）** でボイラープレートを削減する
- **名前付き引数（PHP 8.0）** で可読性を高める
- **Nullsafe 演算子 `?->`（PHP 8.0）** で null チェックの連鎖を簡潔にする
- 依存は Composer で管理し、オートロードは PSR-4 に従う（`require`/`include` の直書きを避ける）
- アンチパターン: 型宣言の省略、`@` によるエラー抑制、グローバル変数・`static` 状態の濫用、生 SQL 文字列連結

### セキュリティ基本

- **SQL: プリペアドステートメント（PDO）** を用いる。`$pdo->prepare()` + バインドで SQL インジェクションを防ぐ（値の文字列連結でクエリを組まない）
- **出力エスケープ**: HTML への出力は `htmlspecialchars($value, ENT_QUOTES, 'UTF-8')` でエスケープする（XSS 対策）
- **パスワード**: `password_hash()` / `password_verify()` を用いる（自前ハッシュ・平文保存を避ける）
- **入力検証**: `filter_var()` / `filter_input()` で型・形式を検証する
- **CSRF 対策はフレームワークの機構を利用**する（Laravel の `@csrf`、Symfony の CSRF トークン、WordPress の nonce 等。自前実装より FW 標準を優先）

## 5. 典型エラーパターンと対処

| エラー | 原因 | 対処 |
|-------|------|------|
| `Fatal error: Uncaught Error: Class "App\Foo" not found` | オートロード未設定・名前空間とディレクトリの不一致・`composer dump-autoload` 未実行 | PSR-4 マッピングとファイル配置・大文字小文字を確認し、`composer dump-autoload` を実行 |
| `Fatal error: Uncaught Error: Call to a member function xxx() on null` | null を返しうる値にメソッドを呼び出した | 事前に null チェック、または Nullsafe 演算子 `?->` を使用。戻り値型を `?T` として明示 |
| `Warning: Undefined array key "xxx"`（PHP 8.0+。旧: `Notice: Undefined index`） | 存在しない配列キーへのアクセス | `isset()` / `array_key_exists()` で確認、または `$arr['xxx'] ?? $default` |
| `Fatal error: Uncaught TypeError: ... must be of type X, Y given` | `strict_types=1` 有効時の引数・戻り値の型不一致 | 呼び出し側の型を修正、または適切に明示キャスト。型宣言を見直す |
| `Warning: Undefined variable $x` | 未定義変数の参照（スコープ外・タイプミス） | 変数の初期化・スコープを確認 |
| `Parse error: syntax error, unexpected ...` | 構文誤り（波括弧・セミコロン欠落等） | 該当行前後を確認。PHP バージョンと構文の対応（8 系新構文を旧環境で使用等）も確認 |

## 6. フレームワーク

| フレームワーク | プロファイル |
|--------------|-------------|
| Laravel / Symfony / WordPress | [frameworks/php-web.md](frameworks/php-web.md) |
