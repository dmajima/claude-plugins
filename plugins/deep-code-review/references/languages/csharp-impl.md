# C# レビュー観点プロファイル — impl details

`csharp.md`（hub）から分離した観点本文。hub の 3.x スタブから該当観点が参照する。
共通前提（節1 識別・節2 準拠規約）・節4 重要度表・節5 FW・節6 動的検証コマンドは `csharp.md`（hub）に残置。
本ファイルは観点 3.1 3.2 3.3 3.4 3.5 3.6 3.8 を収録。

### 3.1 正確性・堅牢性【担当: implementation-engineer】

- [ ] `IDisposable` が `using` 宣言 / `using` ステートメントで確実に破棄されているか（`Stream` / `HttpClient` 誤用 / DB 接続）
- [ ] LINQ の遅延実行を理解した実装か（`IEnumerable<T>` の多重列挙・列挙タイミングのズレ・クエリ内での副作用）
- [ ] `struct` の可変設計・意図しないコピーによるバグがないか
- [ ] 浮動小数点・`decimal` の使い分け（金額計算に `double` を使っていないか）
- [ ] カルチャ依存処理（`ToString()` / `Parse` / 文字列比較）で `CultureInfo` / `StringComparison` が明示されているか
- [ ] `DateTime.Now` と `DateTime.UtcNow` の混在・タイムゾーン考慮漏れがないか

### 3.2 エラー処理・silent-failure【担当: implementation-engineer】

- [ ] **空の catch ブロック**（`catch { }` / `catch (Exception) { }` で何もしない）— 例外の握りつぶし
- [ ] catch して**ログのみ出力し、呼び出し元へ異常を伝えない**まま正常フローを継続していないか
- [ ] `catch (Exception)` の広すぎる捕捉（特定例外型で捕捉すべき箇所）
- [ ] `throw ex;`（スタックトレース破壊）ではなく `throw;` で再スローしているか
- [ ] 例外の代わりに `null` / `false` / マジックナンバーを返して失敗を隠蔽していないか
- [ ] `TryParse` 系の戻り値を無視していないか

### 3.3 型・null 安全【担当: implementation-engineer】

- [ ] NRT（`<Nullable>enable</Nullable>`）有効プロジェクトで `!`（null-forgiving）を安易に使用していないか
- [ ] NRT 無効プロジェクトで public メソッドの引数 null ガードがあるか
- [ ] CS8618 を `required` / コンストラクタ初期化で正しく解消しているか（`= null!;` での抑制は要注意）
- [ ] プリミティブ執着（primitive obsession）: ドメイン概念が `string` / `int` のまま引き回されていないか
- [ ] 不変性: 値オブジェクト・DTO に `record` / `init` / `readonly` が活用されているか
- [ ] キャストの安全性（`as` + null チェック / パターンマッチング vs 直接キャスト）

### 3.4 非同期・並行処理【担当: implementation-engineer / performance-reviewer】

- [ ] **`.Result` / `.Wait()` / `GetAwaiter().GetResult()` の同期ブロッキング**（UI・旧 ASP.NET でデッドロック）→ `await` に置換
- [ ] **`async void`**（イベントハンドラ以外は禁止。例外が捕捉不能）
- [ ] **`await` されていない `Task`**（CS4014 / fire-and-forget が意図的か）
- [ ] ライブラリコードの `ConfigureAwait(false)` 欠落（CA2007）
- [ ] `Task.WaitAll` → `await Task.WhenAll`、`Thread.Sleep` → `await Task.Delay` への置換
- [ ] 共有状態への並行アクセス（`lock` / `Interlocked` / `ConcurrentDictionary` の要否）
- [ ] `CancellationToken` の伝搬漏れ（長時間 I/O・ループ処理）

### 3.5 命名・スタイル【担当: implementation-engineer / linter-static-analysis】

- [ ] 命名規則: クラス/メソッド/プロパティ = PascalCase、インターフェース = `I` + PascalCase、ローカル/引数 = camelCase、private フィールド = `_camelCase`、static = `s_camelCase`、非同期メソッド = `Async` サフィックス
- [ ] `var` の使用指針（右辺から型が明白な場合のみ）
- [ ] Allman スタイル・スペース 4・1 行 1 ステートメント（`.editorconfig` があればそちらに従う）
- [ ] ファイルスコープ名前空間・raw string literal・collection expression 等モダンイディオムとの整合（既存コードのスタイルを優先）
- [ ] アクセス修飾子の明示・フィールドの private 原則

### 3.6 パフォーマンス【担当: performance-reviewer】

- [ ] ループ内での文字列連結（`StringBuilder` を使うべき箇所）
- [ ] ループ内での同期 I/O・DB 呼び出し（N+1。EF Core は frameworks/dotnet.md 参照）
- [ ] LINQ の多重列挙・不要な `ToList()` / `ToArray()` の乱用（もしくは列挙の確定が必要な箇所での欠落）
- [ ] 大量データでの `IEnumerable<T>` 全件メモリ展開（ストリーミング処理・ページングの検討）
- [ ] 高頻度パスでの boxing / クロージャ確保 / LOH 行き大型配列
- [ ] `HttpClient` の都度 new（ソケット枯渇 → `IHttpClientFactory` / static 共有）

### 3.8 コメント・ドキュメント整合【担当: implementation-engineer】

- [ ] XML ドキュメントコメント（`///`）とシグネチャ・実装の不一致（引数名・戻り値・例外）
- [ ] コメントの記述とコードの実挙動の乖離（変更差分でコードだけ変わりコメントが古いまま）
- [ ] コメントアウトされたコードの残留

