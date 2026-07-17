# C# レビュー観点プロファイル

C# コードの変更差分をレビューする際の言語固有観点。プロジェクト独自規約が存在する場合はそちらを優先する（`${CLAUDE_PLUGIN_ROOT}/references/conventions-resolution.md` の優先順位に従う）。

## 1. 識別

| 項目 | 値 |
|------|-----|
| 対象拡張子 | `.cs`（`.csx` は C# スクリプト） |
| マーカーファイル | `*.csproj` / `*.sln` / `Directory.Build.props` / `global.json` / `nuget.config` |
| 世代判別 | `<TargetFramework>` = .NET (Core/5+) 系 / `<TargetFrameworkVersion>` = .NET Framework 系レガシー |

## 2. 準拠規約（プロジェクト規約が無い場合のデフォルト基準）

- Common C# code conventions（Microsoft Learn）
- C# identifier naming rules and conventions（Microsoft Learn）
- Capitalization Conventions（.NET Framework Design Guidelines）

## 3. レビュー観点

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

### 3.7 セキュリティ【担当: security-engineer】

> **埋め込み SQL の横断適用**: `SqlCommand.CommandText` / `ExecuteReader` / Dapper の生 SQL 等でコードに埋め込まれた SQL 文字列には、インジェクション以外にも `${CLAUDE_PLUGIN_ROOT}/references/languages/sql.md` の観点（`SELECT *`・`NOLOCK`・列非明示・NULL 三値論理・方言固有）を併用適用する（`.sql` ファイルが差分に無くても適用。language-detection.md Step 4）。

- [ ] SQL 文字列連結（SQL インジェクション → パラメタライズドクエリ / ORM）
- [ ] パス結合の検証漏れ（`Path.Combine` + 相対パス遡り → path traversal）
- [ ] `BinaryFormatter` 等の危険なデシリアライザ使用
- [ ] 乱数に `Random` を使用（セキュリティ用途は `RandomNumberGenerator`）
- [ ] 機密情報（接続文字列・API キー）のハードコード・ログ出力
- [ ] `ProcessStartInfo` / `Process.Start` へのユーザー入力の未検証受け渡し（コマンドインジェクション）
- [ ] 証明書検証の無効化（`ServerCertificateCustomValidationCallback` で常に true 等）

### 3.8 コメント・ドキュメント整合【担当: implementation-engineer】

- [ ] XML ドキュメントコメント（`///`）とシグネチャ・実装の不一致（引数名・戻り値・例外）
- [ ] コメントの記述とコードの実挙動の乖離（変更差分でコードだけ変わりコメントが古いまま）
- [ ] コメントアウトされたコードの残留

## 4. 典型的な指摘パターン（重要度の目安）

| パターン | 重要度の目安 | 根拠 |
|---------|------------|------|
| SQL 文字列連結（ユーザー入力含む） | Critical | SQL インジェクション |
| `.Result` / `.Wait()`（UI・レガシー ASP.NET 文脈） | High〜Critical | デッドロック・機能停止 |
| 空 catch による例外握りつぶし | High | 障害の無言化・調査不能化 |
| `async void`（非イベントハンドラ） | High | プロセスクラッシュ・例外捕捉不能 |
| await 漏れ（CS4014） | High | 処理順序不定・例外消失 |
| null ガード漏れ（外部入力・public API） | High | NullReferenceException で機能停止 |
| `IDisposable` 破棄漏れ | High〜Medium | リソースリーク |
| `HttpClient` 都度 new | Medium〜High | ソケット枯渇（負荷時に顕在化） |
| ループ内同期 I/O・文字列連結 | Medium〜High | 性能劣化（データ量依存） |
| `CancellationToken` 伝搬漏れ（長時間 I/O・ループ）※同一ファイルの他メソッドが async + CancellationToken を使うのに新規メソッドが同期＝ファイル内一貫性からの逸脱も判断材料 | Medium | キャンセル不能・リソース占有 |
| データアクセス方式の混在（生 ADO.NET × EF Core） | Medium | 保守性・トランザクション境界・接続管理の不整合 |
| `catch (Exception)` 広すぎ捕捉 | Medium | 意図しない例外の隠蔽 |
| 命名規則違反・`var` 指針違反 | Medium〜Low | 可読性・規約整合 |
| モダンイディオム未使用（record 等） | Low | 任意改善（既存スタイルとの整合を優先） |

### NG / OK 例（silent-failure）

```csharp
// NG: 例外を握りつぶし、失敗を null で隠蔽
public Order? GetOrder(int id)
{
    try { return _repo.Find(id); }
    catch { return null; }  // 障害が無言で消える
}

// OK: 捕捉するなら文脈を付与して再スロー or 明示的に処理方針を持つ
public Order GetOrder(int id)
{
    try { return _repo.Find(id); }
    catch (DbException ex)
    {
        throw new OrderRetrievalException($"注文 {id} の取得に失敗", ex);
    }
}
```

## 5. フレームワーク観点

差分に以下の FW が関与する場合、該当プロファイルを併読する:

| 検出条件 | プロファイル |
|---------|-------------|
| `Microsoft.AspNetCore.*` / `Microsoft.NET.Sdk.Web` / EF Core / Blazor / WebForms | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/dotnet.md` |
| `Microsoft.EntityFrameworkCore.*`（ORM 横断観点） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/orm.md` |

## 6. 動的検証コマンド【担当: linter-static-analysis / test-runner】

対応する Bash 権限が許可されている場合のみ実行（なければ SKIPPED 記録）:

| 検証 | コマンド | 判定 |
|------|---------|------|
| ビルド | `dotnet build --no-incremental` | エラー = 強制 FAIL（Critical〜High） |
| フォーマット | `dotnet format --verify-no-changes` | 差分あり = Medium |
| コードスタイル | `dotnet format style --verify-no-changes` / `dotnet format analyzers --verify-no-changes` | 警告内容に応じて Medium〜Low |
| テスト | `dotnet test` | 失敗 1 件ごとに最低 High |
| レガシー（.NET Framework） | `msbuild` + `nuget restore` | 同上 |
