# PHP Web フレームワーク レビュー観点プロファイル

PHP Web フレームワーク（Laravel / Symfony / WordPress）を用いた変更差分をレビューする際の FW 固有観点。言語共通の PHP 観点は `${CLAUDE_PLUGIN_ROOT}/references/languages/php.md` に従い、本ファイルは各 FW 固有の追加観点のみを扱う。プロジェクト独自規約が存在する場合はそちらを優先する（`${CLAUDE_PLUGIN_ROOT}/references/conventions-resolution.md` の優先順位に従う）。

> **規約系統の警告**: Laravel / Symfony は PSR（PSR-12 / PER）準拠だが、**WordPress は独自の WordPress Coding Standards** を用い PSR とは根本的に異なる（タブインデント・snake_case 関数・Yoda 記法・括弧内空白）。同一コードベースで系統を混在させていないかを確認する。

## 1. 対象と検出条件

差分・リポジトリに以下が含まれる場合、該当 FW の観点を適用する。

| フレームワーク | 検出マーカー |
|--------------|-------------|
| Laravel | `composer.json` の require に `laravel/framework` / ルート直下の `artisan` / `app/Http/Controllers` ディレクトリ |
| Symfony | `composer.json` の require に `symfony/framework-bundle`（`symfony/*`）/ `bin/console` / `config/bundles.php` |
| WordPress | `wp-config.php` / `wp-content/` ディレクトリ / `wp-load.php` / テーマの `style.css` ヘッダ・プラグインヘッダコメント |

複数 FW が併存する場合（例: 独立プラグインと Laravel API）は該当セクションを併読する。

## 2. FW ごとのレビュー観点

### 2.1 Laravel

- [ ] **Eloquent の N+1 クエリ**: ループ内でリレーションアクセスしていないか。`with()`（Eager Loading）/ `load()`（遅延 Eager Loading）/ `withCount()` で解消しているか 【担当: performance-reviewer】
- [ ] **マスアサインメント**: モデルに `$fillable`（許可リスト）または `$guarded` が設定されているか。`create()` / `update()` / `fill()` にリクエスト全体（`$request->all()`）を無検証で渡していないか 【担当: security-engineer】
- [ ] **バリデーション**: 入力検証が FormRequest（`rules()`）またはコントローラの `validate()` に集約されているか。未検証のリクエスト値を直接業務処理へ流していないか 【担当: implementation-engineer】
- [ ] **認可**: ミドルウェア / Policy / Gate で認可が行われているか。FormRequest の `authorize()` が常に `true` を返して認可を素通りさせていないか 【担当: security-engineer】
- [ ] **Blade エスケープ（XSS）**: `{!! !!}`（エスケープなし出力）に未信頼データを渡していないか。ユーザー入力は `{{ }}`（自動エスケープ）で出力しているか 【担当: security-engineer】
- [ ] **生 SQL のパラメタライズ**: `DB::raw()` / `whereRaw()` / `DB::select()` に文字列連結でユーザー入力を埋め込んでいないか。バインドパラメータ（`?` / 名前付き）を使っているか 【担当: security-engineer】
- [ ] **API リソースでの機密露出**: `toArray()` / API Resource / `$hidden` の設定で、パスワードハッシュ・トークン等の機密フィールドを応答に含めていないか 【担当: security-engineer】
- [ ] **config / env の参照**: アプリ層（コントローラ / サービス）で `env()` を直接呼んでいないか（`config:cache` 実行時に null 化する）。`config()` 経由で参照しているか 【担当: implementation-engineer】
- [ ] **キュー投入時のシリアライズ**: ジョブへ Eloquent モデルを渡す場合、`SerializesModels` によりディスパッチ時と実行時で状態がずれうる点を考慮しているか。巨大オブジェクト・クロージャを投入していないか 【担当: implementation-engineer】
- [ ] **トランザクション整合**: 複数の書き込みが `DB::transaction()` で原子化されているか。途中失敗で部分コミットが残らないか 【担当: implementation-engineer】
- [ ] **マイグレーションの後方互換**: 列削除・リネーム・NOT NULL 追加がデプロイ中の旧コードを壊さないか。`down()` が定義されロールバック可能か 【担当: implementation-engineer】
- [ ] **Fat Controller**: ビジネスロジックがコントローラに集中していないか（サービス / アクションクラスへ分離されているか） 【担当: implementation-engineer】

### 2.2 Symfony

- [ ] **DI / autowire**: サービスがコンストラクタインジェクションで注入されているか。コンテナ / サービスロケータを引き回してサービス配置を隠していないか 【担当: implementation-engineer】
- [ ] **Doctrine の N+1**: エンティティのリレーションをループ内で辿っていないか。DQL の `JOIN FETCH` / リポジトリでの一括取得で解消しているか 【担当: performance-reviewer】
- [ ] **DQL / クエリのパラメタライズ**: `createQuery()` / QueryBuilder に文字列連結でユーザー入力を渡していないか。`setParameter()` を使っているか 【担当: security-engineer】
- [ ] **フォーム + バリデータ**: 入力検証を Symfony Form + Validator（制約属性）で行っているか。手書き検証が各所に散らばっていないか 【担当: implementation-engineer】
- [ ] **Twig エスケープ（XSS）**: `|raw` フィルタに未信頼データを渡していないか。`autoescape` を安易に無効化していないか 【担当: security-engineer】
- [ ] **Voter での認可**: リソースアクセス制御が Voter / `#[IsGranted]` で一元化されているか。コントローラに認可判定が散在していないか 【担当: security-engineer】
- [ ] **Serializer の露出範囲**: シリアライズグループ（`#[Groups]`）で機密プロパティを応答に含めていないか 【担当: security-engineer】
- [ ] **イベントリスナ / サブスクライバの副作用**: リスナ内の重い処理・DB 書き込み・例外送出が意図せぬ副作用を起こさないか。実行順（priority）への暗黙依存がないか 【担当: implementation-engineer】

### 2.3 WordPress

> WordPress は **WordPress Coding Standards** に従う。PSR 前提のツール（Laravel Pint 等）・規約をそのまま適用していないかを確認する。

- [ ] **REST API の permission_callback**: `register_rest_route()` の各エンドポイントに `permission_callback` が定義されているか。欠落・`__return_true` の濫用は認可バイパス 【担当: security-engineer】
- [ ] **nonce + 権限チェックの両方**: フォーム / AJAX / 管理操作で nonce 検証（`check_admin_referer()` / `wp_verify_nonce()` / `check_ajax_referer()`）と権限チェック（`current_user_can()`）を **両方** 行っているか。片方だけは不十分 【担当: security-engineer】
- [ ] **サニタイズとエスケープの使い分け**: 入力は `sanitize_text_field()` / `sanitize_email()` / `absint()` 等でサニタイズ、出力は文脈に応じ `esc_html()` / `esc_attr()` / `esc_url()` / `esc_js()` でエスケープしているか。混同・欠落がないか 【担当: security-engineer】
- [ ] **$wpdb->prepare**: 直接 SQL を組む際に `$wpdb->prepare()` でプレースホルダを使っているか。`$_POST` / `$_GET` / `$_REQUEST` を文字列連結でクエリに埋め込んでいないか 【担当: security-engineer】
- [ ] **フックの優先度・解除**: `add_action()` / `add_filter()` の優先度が適切か。`remove_action()` / `remove_filter()` でフック名・優先度・引数数が登録時と一致しているか（不一致だと解除されない） 【担当: implementation-engineer】
- [ ] **WP Coding Standards 準拠**: タブインデント・snake_case 関数名・Yoda 記法・プレフィックスによる名前衝突回避に従っているか（`phpcs --standard=WordPress` で検査可能） 【担当: implementation-engineer】
- [ ] **スクリプト / スタイルの読み込み**: `<script>` / `<link>` の直書きではなく `wp_enqueue_script()` / `wp_enqueue_style()` を使っているか 【担当: web-designer】
- [ ] **入出力の分岐テスト**: サニタイズ / nonce / 権限チェックの分岐（権限なし・nonce 不正のケース）にテストが用意されているか 【担当: test-engineer】

### 2.4 検出のヒント（grep 例）

差分の該当箇所を素早く特定するための検索パターン。ヒットした周辺で上記チェックリストを確認する。

| リスク | 検索パターン（例） | 確認事項 |
|-------|------------------|---------|
| Blade / Twig のエスケープなし出力 | `{!!` / `\|raw` | 出力値が未信頼データでないか |
| 生 SQL の連結 | `DB::raw` / `whereRaw` / `createQuery(` | バインドパラメータを使っているか |
| マスアサインメント | `->fill(` / `::create(` / `$request->all()` | `$fillable` / `$guarded` の設定有無 |
| `env()` のアプリ層直呼び | `env(` | `config/` 以外での使用でないか |
| WP REST エンドポイント | `register_rest_route` | 近傍に `permission_callback` があるか |
| WP 直接 SQL | `$wpdb->query` / `$wpdb->get_` | `$wpdb->prepare()` の有無 |
| WP 入力の未検証使用 | `$_POST` / `$_GET` / `$_REQUEST` | nonce 検証・サニタイズの有無 |

## 3. 典型的な指摘パターン（重要度の目安）

| パターン | 重要度の目安 | 根拠 |
|---------|------------|------|
| REST API エンドポイントの `permission_callback` 欠落 / `__return_true`（WP） | Critical | 認可バイパス・情報漏洩 |
| `DB::raw` / `whereRaw` / `$wpdb` への文字列連結（ユーザー入力含む） | Critical | SQL インジェクション |
| Blade `{!! !!}` / Twig `\|raw` へ未信頼データ | Critical〜High | 格納 / 反射型 XSS |
| マスアサインメント（`$fillable`/`$guarded` 未設定 + `$request->all()`） | High | 権限昇格・意図しない列更新 |
| nonce 検証のみ / 権限チェックのみ（片方欠落・WP） | High | CSRF または認可不備 |
| 認可チェック欠落（Policy / Voter / `current_user_can` 不使用） | High | 不正操作・水平/垂直権限昇格 |
| API 応答での機密フィールド露出（`$hidden` / Groups 不備） | High | 認証情報・PII 漏洩 |
| Eloquent / Doctrine の N+1 | High〜Medium | 性能劣化（データ量依存） |
| 後方互換を壊すマイグレーション（列削除・NOT NULL 追加） | High〜Medium | デプロイ中の旧コード障害 |
| アプリ層での `env()` 直呼び（config キャッシュ時） | Medium | 本番で設定値が null 化 |
| フック解除の引数不一致（WP `remove_action`） | Medium | フックが外れず二重実行 |
| Fat Controller / イベントリスナの隠れた副作用 | Medium〜Low | 保守性低下・テスト困難 |
| WP Coding Standards / PSR 系統の混在 | Medium〜Low | 規約整合・可読性 |

### NG / OK 例（Blade の XSS）

```php
{{-- NG: ユーザー入力をエスケープなしで出力 --}}
<div>{!! $comment->body !!}</div>

{{-- OK: 自動エスケープ。HTML を許可する必要があれば purifier 等で無害化してから --}}
<div>{{ $comment->body }}</div>
```

### NG / OK 例（WordPress の認可 + nonce）

```php
// NG: nonce も権限も確認せず更新
update_option( 'site_title', $_POST['title'] );

// OK: nonce 検証 + 権限チェック + サニタイズ
if ( check_admin_referer( 'save_settings' ) && current_user_can( 'manage_options' ) ) {
    update_option( 'site_title', sanitize_text_field( wp_unslash( $_POST['title'] ) ) );
}
```

### NG / OK 例（Laravel の N+1）

```php
// NG: ループ内でリレーションアクセス → 投稿数 + 1 回のクエリ
$posts = Post::all();
foreach ($posts as $post) {
    echo $post->author->name;   // 各反復で author を都度クエリ
}

// OK: Eager Loading で 2 クエリに集約
$posts = Post::with('author')->get();
foreach ($posts as $post) {
    echo $post->author->name;
}
```

## 4. 関連プロファイル参照

差分の内容に応じて以下を併読する。

| 対象 | プロファイル |
|------|-------------|
| PHP 言語共通の観点（命名・エラー処理・型・silent-failure） | `${CLAUDE_PLUGIN_ROOT}/references/languages/php.md` |
| ORM 横断観点（Eloquent / Doctrine のクエリ・マイグレーション安全性） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/orm.md` |
| フロントエンド（Blade / Twig が生成する HTML / CSS の品質） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/frontend-tooling.md` |
| 指摘の重要度付与・重複統合 | `${CLAUDE_PLUGIN_ROOT}/references/severity-ranking.md` |
