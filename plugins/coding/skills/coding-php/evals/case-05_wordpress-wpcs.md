# Case 05: wp-config.php 検出による WordPress Coding Standards への切替

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「このテーマに新着記事一覧を表示する関数を追加して」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | PHP プロジェクト。ルートに `wp-config.php`、`wp-content/themes/<theme>/` 配下にテーマ。`composer.json` に `laravel/framework` / `symfony/*` は無い。既存コードは WordPress 慣習（snake_case 関数・タブインデント）で一貫。ユーザの直接依頼で `coding-php` を単独起動 |

## 期待動作

単独実行モードの実行フロー 5 段のうち、FW 検出と規約切替が焦点になる。

### ステップ1〜2: 規約解決・FW 確認（WordPress 検出）
- 独自規約の走査中に `wp-config.php` / `wp-content/` を検出し、[references/frameworks/php-web.md](../references/frameworks/php-web.md) セクション 1 の検出マーカーに従い **WordPress** と判定する
- 重要な制約「WordPress を対象とする場合は PSR ではなく WordPress Coding Standards に従う（同一コードベースで規約を混在させない）」に従い、PSR-12 ではなく **WPCS** を適用対象に切り替える（php-web.md セクション 4）

### ステップ3: 実装（WPCS 準拠）
- 命名・書式は WPCS に従う: 関数名 snake_case（`myprefix_get_recent_posts()`）・タブインデント・括弧内の空白（`foo( $bar )`）・Yoda 記法・プレフィックスによる名前衝突回避
- 出力は late escaping（`esc_html()` 等）、入力はサニタイズ、DB アクセスは `$wpdb->prepare()` でプレースホルダを使う
- スクリプト / スタイルは `wp_enqueue_scripts` 内で `wp_enqueue_script()` / `wp_enqueue_style()` を使う（テンプレート直書きを避ける）

### ステップ4〜5: 検証・報告
- 利用可能なら `phpcs --standard=WordPress` で検証する。実行不能な検証は SKIPPED として報告する
- 適用規約が **WPCS（PSR ではない）** である旨・根拠（wp-config.php 起点の WordPress 判定）を報告する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 適用規約 | WordPress Coding Standards（PSR-12 ではない） |
| ユーザへの確認 | 規約の矛盾・方針の拮抗がなければ AskUserQuestion 不発火 |
| 生成ファイル | WPCS 準拠のコード変更（テーマの `functions.php` 等） |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは FW 検出 = WordPress（`wp-config.php` 起点）である。
既存 case-01 / case-02 は Laravel を対象に PSR 準拠を検証しており、本ケースは WordPress の **WPCS 切替**（PSR とは根本的に異なる規約）という非対称な分岐を補完する。適用規約は php-web.md セクション 4 の WPCS（命名・インデント・エスケープ・nonce・`$wpdb->prepare()`）に基づく。

## 関連ケース

- [case-01_standalone-basic.md](case-01_standalone-basic.md)（Laravel / PSR 準拠の基本フローとの対比）
- [case-04_convention-conflict.md](case-04_convention-conflict.md)（PSR ベースの機械設定とユーザ指示の矛盾ケース）
