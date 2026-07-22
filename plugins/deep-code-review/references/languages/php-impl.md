# PHP レビュー観点プロファイル — impl details

`php.md`（hub）から分離した観点本文。hub の 3.x スタブから該当観点が参照する。
共通前提（節1 識別・節2 準拠規約）・節4 重要度表・節5 FW・節6 動的検証コマンドは `php.md`（hub）に残置。
本ファイルは観点 3.1 3.2 3.3 3.4 3.5 3.6 3.8 を収録。

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

### 3.8 コメント・ドキュメント整合【担当: implementation-engineer】

- [ ] PHPDoc（`@param` / `@return` / `@throws` / `@var`）とシグネチャ・実装の不一致（引数名・型・例外）
- [ ] PHPDoc の型記述（`@param array<string, int>` 等）と実際の型宣言・実挙動の乖離
- [ ] コメントの記述とコードの実挙動の乖離（変更差分でコードだけ変わりコメントが古いまま）
- [ ] `@deprecated` / `@internal` タグとコード実態の不整合、型エイリアス（`@phpstan-type` / `@template`）の陳腐化
- [ ] コメントアウトされたコードの残留

