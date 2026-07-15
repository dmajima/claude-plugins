# PHP Web フレームワークプロファイル

対象言語プロファイル: [../conventions.md](../conventions.md)（PHP 言語規約はそちらに従う。本ファイルは各フレームワーク固有の規約のみ）

> **重要**: Laravel と Symfony は PHP-FIG の PSR（PSR-1 / PSR-12 / PER）に準拠する。一方 **WordPress は独自の WordPress Coding Standards を用い、PSR とは大きく異なる**（後述のセクション 4 を必読）。同一コードベースで複数 FW の規約を混在させないこと。

## 1. 検出

| フレームワーク | 検出マーカー |
|--------------|-------------|
| Laravel | `composer.json` の require に `laravel/framework`／ルート直下の `artisan` ファイル／`app/Http/Controllers` ディレクトリ |
| Symfony | `composer.json` の require に `symfony/framework-bundle`（`symfony/*`）／`bin/console`／`config/bundles.php` |
| WordPress | `wp-config.php`／`wp-content/` ディレクトリ／`wp-load.php`／テーマの `style.css` ヘッダ・プラグインヘッダコメント |

## 2. Laravel

### 2.1 プロジェクト構造・配置規則

| ディレクトリ | 役割 |
|------------|------|
| `app/Http/Controllers` | コントローラ |
| `app/Models` | Eloquent モデル |
| `app/Http/Requests` | FormRequest（バリデーション） |
| `app/Providers` | サービスプロバイダ |
| `routes/`（`web.php` / `api.php` / `console.php`） | ルート定義 |
| `database/migrations` | マイグレーション |
| `database/seeders` / `database/factories` | シーダー / ファクトリ |
| `resources/views` | Blade テンプレート（`.blade.php`） |
| `config/` | 設定ファイル |
| `public/` | 公開ディレクトリ（`index.php`） |

### 2.2 FW 固有の命名・実装規約

**Eloquent 命名規約（規約による自動対応。命名を揃えれば設定を省略できる）**

| 対象 | 規則 | 例 |
|------|------|-----|
| モデル | 単数形 PascalCase | `User`, `OrderItem` |
| テーブル | モデル名の複数形 snake_case | `users`, `order_items` |
| 主キー | `id`（既定） | `id` |
| 外部キー | `<単数形モデル名>_id` snake_case | `user_id` |
| ピボットテーブル | 関連 2 モデルの単数形をアルファベット順に snake_case で連結 | `role_user`（`role` と `user`） |
| タイムスタンプ列 | `created_at` / `updated_at` | |
| コントローラ | リソース名 + `Controller`（PascalCase） | `UserController` |

**マイグレーション**: `database/migrations/` にタイムスタンプ付きファイル名（`2024_01_01_000000_create_users_table.php`）。`up()` / `down()` メソッドと `Schema` ファサードで定義する。

```php
Schema::create('orders', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained();
    $table->timestamps();
});
```

**Blade テンプレート**: `{{ $var }}` は自動エスケープ出力、`{!! $var !!}` はエスケープなし出力（信頼済みデータのみ）。`@if` / `@foreach` / `@extends` / `@section` / `@yield` / `@include` などのディレクティブ、フォームには `@csrf` を置く。

**バリデーション（FormRequest）**: `php artisan make:request StoreUserRequest` で生成し、`rules()` にルール、`authorize()` に認可を定義する。コントローラを薄く保つ。

```php
public function rules(): array
{
    return [
        'email' => ['required', 'email', 'unique:users'],
        'name'  => ['required', 'string', 'max:255'],
    ];
}
```

**コーディングスタイル**: Laravel は公式フォーマッタ **Laravel Pint**（PSR-12 ベース）を採用する（`../conventions.md` の PSR-12 / PER に準拠）。

### 2.3 ツールチェーン

| 用途 | コマンド |
|------|---------|
| scaffold | `php artisan make:controller` / `make:model -m`（モデル + マイグレーション）/ `make:migration` / `make:request` / `make:seeder` / `make:factory` |
| dev | `php artisan serve` |
| migrate | `php artisan migrate` / `migrate:rollback` / `migrate:fresh --seed` |
| test | `php artisan test`（または `vendor/bin/phpunit`） |
| format | `./vendor/bin/pint`（Laravel Pint） |
| REPL | `php artisan tinker` |

### 2.4 ベストプラクティス・アンチパターン

- マスアサインメント対策としてモデルに `$fillable` / `$guarded` を適切に設定する
- N+1 クエリを Eager Loading（`with()`）で回避する
- バリデーションは FormRequest に集約し、ビジネスロジックはサービス / アクションクラスへ寄せる（Fat Controller を避ける）
- 設定値は `config/` 経由で参照する（`env()` の直接呼び出しは config ファイル内に限定する。設定キャッシュ時に `env()` が null になるため）
- SQL は Eloquent / クエリビルダを用いる（プレースホルダを自動使用）。生 SQL は `DB::select()` でバインドする
- アンチパターン: `{!! !!}` に未信頼データを渡す、コントローラへのロジック集中、`env()` のアプリ層直呼び

## 3. Symfony

### 3.1 プロジェクト構造・配置規則

| ディレクトリ | 役割 |
|------------|------|
| `src/Controller` | コントローラ |
| `src/Entity` | Doctrine エンティティ |
| `src/Repository` | リポジトリ（クエリのカプセル化） |
| `config/`（`routes.yaml` / `services.yaml` / `packages/`） | 設定・DI・ルーティング |
| `templates/` | Twig テンプレート（`.html.twig`） |
| `migrations/` | Doctrine マイグレーション |
| `public/` | 公開ディレクトリ（`index.php`） |
| `bin/console` | CLI エントリポイント |

### 3.2 FW 固有の命名・実装規約

**属性ベースルーティング**（PHP 8 attributes。旧来のアノテーションから移行済み）:

```php
#[Route('/orders/{id}', name: 'order_show', methods: ['GET'])]
public function show(int $id): Response
{
    // ...
}
```

**Doctrine ORM**: エンティティに属性でマッピングを付与する。

```php
#[ORM\Entity(repositoryClass: OrderRepository::class)]
class Order
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    private ?int $id = null;
}
```

**コーディング規約**: Symfony 公式コーディング規約（https://symfony.com/doc/current/contributing/code/standards.html）は PSR-1 / PSR-2（現 PSR-12）/ PSR-4 に準拠したうえで、独自規則を追加する。主な独自規則（確定しているもの）:

- 比較には identical comparison（`===` / `!==`）を使う（型の自動変換が必要な場合を除く）
- 論理演算子は `&&` / `||` を使う（`and` / `or` は使わない）
- コンマ区切りの後に空白 1 個を入れる。二項演算子（`==`, `&&` 等）の前後に空白 1 個を入れる（連結演算子 `.` は例外規定のため公式規約を参照）
- 変数・関数・メソッド名・引数は camelCase を使う。設定パラメータと Twig テンプレート変数は snake_case を使う
- 命名サフィックス / プレフィックス: 抽象クラスは `Abstract` プレフィックス、インターフェースは `Interface` サフィックス、トレイトは `Trait` サフィックス、例外クラスは `Exception` サフィックスを付ける
- 複数行配列では最後の要素の後にも末尾コンマを付ける。配列は短縮構文 `[]` を使う
- `return` 文の前に空行を 1 行入れる（メソッド内に文が 1 つだけの場合を除く）
- private / protected のプロパティ・メソッドにアンダースコアプレフィックスを付けない

### 3.3 ツールチェーン

| 用途 | コマンド |
|------|---------|
| scaffold | `php bin/console make:controller` / `make:entity` / `make:migration`（MakerBundle） |
| dev | `symfony server:start`（Symfony CLI） |
| migrate | `php bin/console doctrine:migrations:migrate` |
| cache | `php bin/console cache:clear` |
| test | `php bin/phpunit`（または `vendor/bin/phpunit`） |
| debug | `php bin/console debug:router` / `debug:container` / `debug:autowiring` |

### 3.4 ベストプラクティス・アンチパターン

- サービスは `config/services.yaml` の autowiring / autoconfigure を活用して DI する
- コントローラは薄く保ち、ロジックはサービスへ寄せる。クエリはリポジトリにカプセル化する
- Twig は出力を既定で自動エスケープする（信頼済み HTML のみ `|raw` を使う）
- フォーム・バリデーションは Symfony Form + Validator コンポーネント（制約属性）で行う
- 環境依存値は `.env` + `%env(...)%` パラメータ経由で扱う
- アンチパターン: PSR とは無関係な独自スタイルの持ち込み、`|raw` への未信頼データ、コントローラへのロジック集中

## 4. WordPress

> **PSR との差異に関する警告（必読）**: WordPress は独自の **WordPress Coding Standards**（https://developer.wordpress.org/coding-standards/wordpress-coding-standards/php/）に従う。命名規則・インデント・空白・波括弧の規約が PHP-FIG の PSR とは根本的に異なる。Laravel / Symfony の感覚（PSR）でコードを書くと規約違反になるため、WordPress のテーマ・プラグイン開発では下記に厳密に従うこと。

### 4.1 プロジェクト構造・配置規則

| 対象 | 配置・構成 |
|------|-----------|
| テーマ | `wp-content/themes/<theme>/`。`style.css`（テーマヘッダ必須）、`functions.php`、テンプレート階層（`index.php` / `header.php` / `footer.php` / `single.php` / `page.php` / `archive.php` 等） |
| プラグイン | `wp-content/plugins/<plugin>/`。メインファイル先頭にプラグインヘッダコメント |
| 設定 | ルートの `wp-config.php` |

### 4.2 FW 固有の命名・実装規約（PSR と大きく異なる）

出典: WordPress Coding Standards（https://developer.wordpress.org/coding-standards/wordpress-coding-standards/php/）

| 対象 | WordPress の規則 | PSR との差異 |
|------|-----------------|-------------|
| インデント | **タブ**（整列にのみスペース） | PSR は 4 スペース |
| 関数名 | **snake_case**（小文字 + アンダースコア）`get_the_title()` | PSR-1 のメソッドは camelCase |
| 変数 | snake_case `$post_id` | |
| クラス名 | 単語の先頭を大文字にしアンダースコアで連結 `class WP_Query` / `class Walker_Category` | PSR は `PascalCase`（アンダースコア無し） |
| 定数 | UPPER_SNAKE_CASE `DOING_AJAX` | PSR と同様 |
| 括弧内の空白 | **括弧の内側に空白を入れる** `foo( $bar )` / `if ( $condition )` | PSR は空白なし `foo($bar)` |
| 波括弧 | 制御構造でも常に波括弧を使い、開き波括弧は同じ行 | クラス/メソッドの `{` 位置が PSR と異なる |
| 条件式 | **Yoda 記法**（代入ミス防止）`if ( true === $the_force )` | PSR は規定なし |

**名前空間の代替（プレフィックス）**: WordPress コアや多くのテーマ・プラグインは PHP 名前空間をあまり使わず、**関数・クラス・グローバル変数に一意なプレフィックス**を付けて名前衝突を防ぐ（例: `myplugin_init()`、`class MyPlugin_Admin`、`$myplugin_options`）。

**フック（action / filter）**: 拡張点はフック経由で連携する。

```php
add_action( 'init', 'myplugin_init' );                       // アクション登録
do_action( 'myplugin_after_setup' );                          // アクション発火
add_filter( 'the_content', 'myplugin_filter_content' );       // フィルタ登録
$value = apply_filters( 'myplugin_price', $value );           // フィルタ適用
```

**スクリプト・スタイルの読み込み**: `<script>` / `<link>` の直書きを避け、`wp_enqueue_scripts` アクション内で `wp_enqueue_script()` / `wp_enqueue_style()` を使う。

**エスケープ（出力直前に行う「late escaping」）**: `esc_html()`（HTML）、`esc_attr()`（属性値）、`esc_url()`（URL）、`esc_js()`（インライン JS）、`esc_textarea()`（テキストエリア）。国際化と併用する `esc_html__()` / `esc_attr_e()` 等もある。

**サニタイズ（入力時）**: `sanitize_text_field()` / `sanitize_email()` / `absint()` 等で入力を無害化する。

**nonce（CSRF 対策）**: フォーム・AJAX リクエストには nonce を必須化する。生成は `wp_nonce_field()` / `wp_create_nonce()`、検証は `wp_verify_nonce()` / `check_admin_referer()` / `check_ajax_referer()`。

**DB アクセス**: グローバル `$wpdb` を用い、`$wpdb->prepare()` でプレースホルダを使う（SQL インジェクション対策）。

### 4.3 ツールチェーン

| 用途 | コマンド |
|------|---------|
| 規約検査 | `phpcs --standard=WordPress`（PHP_CodeSniffer + WordPress Coding Standards / WPCS ルールセット） |
| CLI 操作 | WP-CLI: `wp plugin ...` / `wp theme ...` / `wp db ...` |
| scaffold | WP-CLI: `wp scaffold plugin <name>` / `wp scaffold _s`（テーマ） |
| ローカル環境 | `wp-env`（公式の Docker ベース環境） |
| test | PHPUnit + WordPress test suite（`WP_UnitTestCase`） |

### 4.4 ベストプラクティス・アンチパターン

- すべての出力を出力直前にエスケープ（late escaping）、すべての入力をサニタイズ・検証する
- フォーム・AJAX には nonce による検証を必須化する
- DB クエリは `$wpdb->prepare()` でプレースホルダを使う（文字列連結でクエリを組まない）
- 関数・クラス・グローバル変数はプレフィックスで名前衝突を回避する
- スクリプト / スタイルは `wp_enqueue_*` で読み込む（テンプレートへの直書きを避ける）
- 翻訳可能文字列は国際化関数（`__()` / `_e()` / `esc_html__()`）でテキストドメイン付きにする
- アンチパターン: PSR 前提のツール・規約をそのまま WordPress に適用する、`$_POST` / `$_GET` を未検証・未サニタイズで使用する、WordPress コアファイルの直接改変
