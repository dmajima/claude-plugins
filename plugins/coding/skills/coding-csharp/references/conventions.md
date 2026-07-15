# C# 言語プロファイル

## 1. 識別（プロジェクト検出）

| 項目 | 値 |
|------|-----|
| 対象拡張子 | `.cs`（`.csx` は C# スクリプト） |
| マーカーファイル | `*.csproj`（プロジェクト）/ `*.sln`（ソリューション）/ `Directory.Build.props` / `global.json` / `nuget.config` |

- SDK スタイルの `*.csproj` は `<Project Sdk="Microsoft.NET.Sdk">` を持つ（Web は `Microsoft.NET.Sdk.Web`）。
- `*.csproj` に `<TargetFramework>` があれば .NET（Core/5+）系、`<TargetFrameworkVersion>` の旧形式なら .NET Framework 系のレガシー構成。

## 2. デファクトスタンダード規約

**準拠規約**:
- Common C# code conventions（Microsoft Learn） https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions
- C# identifier naming rules and conventions（Microsoft Learn） https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/identifier-names
- Capitalization Conventions（.NET Framework Design Guidelines） https://learn.microsoft.com/dotnet/standard/design-guidelines/capitalization-conventions

### 2.1 命名規則

| 対象 | 規則 | 例 |
|------|------|-----|
| クラス / 構造体 / レコード / 列挙型 / デリゲート | PascalCase | `OrderService`, `PhysicalAddress` |
| インターフェース | PascalCase + `I` プレフィクス | `IWorkerQueue` |
| メソッド / ローカル関数 | PascalCase | `StartEventProcessing` |
| プロパティ / イベント / public フィールド | PascalCase | `WorkerQueue`, `Length` |
| 定数（`const` / ローカル定数、アクセス修飾子を問わず） | PascalCase | `InfiniteTimeout` |
| 名前空間 | PascalCase（逆ドメイン記法推奨） | `MyApp.Services.Payments` |
| ローカル変数 / メソッド引数 | camelCase | `someNumber`, `isValid` |
| private / internal の非定数インスタンスフィールド | `_camelCase`（先頭アンダースコア） | `_workerQueue` |
| private / internal の static フィールド | `s_camelCase` | `s_workerQueue` |
| `[ThreadStatic]` フィールド | `t_camelCase` | `t_timeSpan` |
| 型パラメータ | `T` または `TDescriptive`（PascalCase） | `T`, `TKey`, `TResult` |
| 非同期メソッド | 動詞 + `Async` サフィックス | `GetDataAsync` |
| 属性クラス | 末尾に `Attribute` | `SerializableAttribute` |

補足規則（出典: C# identifier naming rules and conventions）:
- 列挙型は非フラグを単数名詞、`[Flags]` を複数名詞にする。
- 2 文字の頭字語は両方大文字（`IOStream`）、3 文字以上は先頭のみ大文字（`HtmlTag`）。camelCase 先頭の 2 文字頭字語は両方小文字（`ioStream`）。
- 連続する 2 つのアンダースコア（`__`）はコンパイラ予約のため識別子に使わない。
- レコードの位置パラメータは public プロパティになるため PascalCase（`record Person(string FirstName, string LastName)`）。class / struct の primary constructor パラメータは camelCase。
- `Async` サフィックスは、コードから明示的に呼ばれないメソッド（イベントハンドラ、Web コントローラのアクション等）には必須ではない。

### 2.2 インデント・フォーマット

| 項目 | 規定 |
|------|------|
| インデント | スペース 4 個（タブ不使用） |
| 波括弧 | Allman スタイル（開き波括弧・閉じ波括弧をそれぞれ独立した新しい行に置き、現在のインデントに揃える） |
| 1 行あたり | 1 ステートメント / 1 宣言 |
| 行長目安 | 公式規約に本番コード用の厳密な上限はない（Microsoft ドキュメントのサンプルは可読性のため 65 文字だが、これはドキュメント表示用の指針）。改行は二項演算子の前で行う。`.editorconfig` の `max_line_length` で任意に規定可能 |
| 文字列補間 | 位置指定より式ベースの補間 `$"{student.Last}"` を使う |
| 名前空間宣言 | 新規コードはファイルスコープ名前空間（`namespace MyApp.Models;`）を使う |
| `using` ディレクティブ | 名前空間宣言の外側（ファイル先頭）に置く（完全修飾名として解釈され明確になる） |

出典: Common C# code conventions（Style guidelines / Language guidelines）、Namespaces and using directives https://learn.microsoft.com/dotnet/csharp/fundamentals/program-structure/namespaces

### 2.3 主要スタイル規則

- `var` の使用指針（出典: Common C# code conventions / Implicitly typed local variables https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/implicitly-typed-local-variables）:
  - 代入の右辺から型が明白な場合（`new` 演算子・明示的キャスト・リテラル代入）は `var` を使う。例: `var message = "This is clearly a string.";`
  - 右辺から型が明白でない場合（例: メソッドの戻り値）は明示的な型を書く。例: `int numberOfIterations = Convert.ToInt32(Console.ReadLine());`
  - LINQ クエリの結果（匿名型・ネストした総称型を返す）や `foreach`/`for` のループ変数のうち、匿名型を扱うものは `var` が必須。`foreach` の要素型は明白でないことが多いため、この場合は明示型を推奨。
  - フィールド（クラススコープ）には `var` を使えない（ローカル変数のみ）。
- コメント: 単一行 `//` を優先。`//` の後に 1 スペース、先頭大文字・末尾ピリオド。public メンバーの説明は XML ドキュメントコメント（`///`）を使う。
- 型メンバーへのアクセス修飾子は明示する。フィールドは原則 private とし public/protected のプロパティで公開する。
- モダン C# のイディオムを優先: raw string literal（`"""..."""`）、collection expression（`string[] vowels = ["a", "e"];`）、target-typed `new`（`List<string> names = new();`）、`required` プロパティ、`Func<>`/`Action<>`（独自デリゲート型定義より優先）。

## 3. ツールチェーン

| 用途 | コマンド | 備考 |
|------|---------|------|
| ビルド | `dotnet build` | SDK スタイルプロジェクト。復元は `dotnet restore`（build 時に暗黙実行） |
| 実行 | `dotnet run` | |
| テスト | `dotnet test` | xUnit / NUnit / MSTest 等のテストプロジェクトを実行 |
| フォーマット | `dotnet format` | `.editorconfig` に基づき整形。`--verify-no-changes` で差分検証（CI 用）、`dotnet format style` / `dotnet format analyzers` でサブセット適用 |
| パッケージ追加 | `dotnet add package <Id>` | NuGet。削除は `dotnet remove package <Id>` |
| プロジェクト生成 | `dotnet new <template>` | 例: `dotnet new console`, `dotnet new editorconfig` |
| レガシービルド（.NET Framework） | `msbuild`（MSBuild）/ `nuget restore` | 旧形式 `*.csproj`・`packages.config`。Visual Studio / `msbuild.exe` でビルド |

出典: dotnet format https://learn.microsoft.com/dotnet/core/tools/dotnet-format

### プロジェクト規約ファイル（存在時は本プロファイルより優先）

| ファイル | 内容 |
|---------|------|
| `.editorconfig` | インデント・改行・文字コードと、.NET コードスタイル規則（`dotnet_*` / `csharp_*` オプション、`IDExxxx` 規則の重大度）。.NET が公式サポートし、Visual Studio のオプションより優先される。出典: https://learn.microsoft.com/visualstudio/ide/create-portable-custom-editor-options |
| `Directory.Build.props` / `Directory.Build.targets` | ソリューション横断の MSBuild 既定プロパティ（`<Nullable>`, `<LangVersion>`, `<TreatWarningsAsErrors>` 等） |
| `*.csproj` の `<PropertyGroup>` | `<EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>` でビルド時にコードスタイル（`IDExxxx`）を警告/エラー化。出典: https://learn.microsoft.com/dotnet/fundamentals/code-analysis/overview |
| StyleCop.Analyzers / Roslyn Analyzer（`<PackageReference>`） | 追加の静的解析・スタイル規則。`.editorconfig` で個別ルールの重大度を設定 |
| `.globalconfig` | `.editorconfig` に紐づかないグローバルなアナライザ設定 |

## 4. イディオム・ベストプラクティス

- **async/await**: I/O バウンド処理は `async`/`await` で書く。戻り値の型は `Task` / `Task<T>`（高頻度・同期完了パスでは `ValueTask` / `ValueTask<T>` を検討）。
- **`.Result` / `.Wait()` の同期ブロッキング禁止**: 単一スレッド `SynchronizationContext`（UI スレッド、旧 ASP.NET リクエストスレッド）でデッドロックを引き起こす。`await` を使う。`Task.WaitAll` → `await Task.WhenAll`、`Thread.Sleep` → `await Task.Delay` に置き換える。出典: Common async/await bugs https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/common-async-bugs
- **ライブラリコードの `ConfigureAwait(false)`**: 呼び出し元のコンテキストへ戻る必要がないライブラリの `await` には `ConfigureAwait(false)` を付け、デッドロック回避とパフォーマンス向上を図る（アナライザ規則 CA2007）。UI を更新するアプリ側コードでは通常コンテキストを捕捉する。出典: https://learn.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca2007
- **`async void` はイベントハンドラのみ**: それ以外は `Task` を返す。`async void` は例外を呼び出し元で捕捉できず、テストが困難。
- **null 許容参照型（NRT）**: 新規プロジェクトは `<Nullable>enable</Nullable>` を有効化し、`?` で null 許容性を明示。非 null 参照型の未初期化警告（CS8618）は `required` プロパティ（C# 11 以降）またはコンストラクタ初期化で解消する。
- **`using` 宣言**: `IDisposable` は `using` 宣言（`using var stream = ...;`）または `using` ステートメントで確実に破棄する。
- **パターンマッチング**: `switch` 式・プロパティパターン・型パターンで条件分岐を簡潔に書く。
- **LINQ**: フィルタ（`where`）を他の句より前に置いて処理対象を絞る。遅延実行（deferred execution）に注意し、`foreach` での列挙タイミングを意識する。LINQ 内での非同期ラムダはデッドロックの温床になるため慎重に扱う。
- **`record`**: 不変（immutable）な値オブジェクトやデータ転送には `record` / `record struct` を使う。

## 5. 典型エラーパターンと対処

| エラー | 原因 | 対処 |
|-------|------|------|
| CS0246: The type or namespace name '...' could not be found | 型・名前空間が見つからない（`using` 不足、アセンブリ/パッケージ未参照、型名のタイポ） | 該当名前空間の `using` を追加、`dotnet add package` / 参照追加。復元が疑わしければ `dotnet restore` |
| CS0234: The type or namespace name does not exist in the namespace | 名前空間内に型が存在しない（アセンブリ参照不足） | 必要なアセンブリ/パッケージを参照。バージョン不整合を確認 |
| CS8618: Non-nullable variable must contain a non-null value when exiting constructor | NRT 有効下で非 null 参照型プロパティ/フィールドが未初期化 | `required` 修飾、コンストラクタで初期化、既定値代入（`= string.Empty;`）、または `?` で null 許容化 |
| CS1998: This async method lacks 'await' operators | `async` を付けたが本体に `await` がない | 不要なら `async` を外す、または `await` を追加 |
| CS4014: Because this call is not awaited, execution continues... | `Task` を返す呼び出しを await していない（fire-and-forget） | 意図的でなければ `await` を付ける |
| NU1101: Unable to find package '...'. No packages exist with this id | NuGet がパッケージ ID をどのソースでも解決できない | パッケージ ID/バージョンを確認、`nuget.config` のソース設定を確認（`https://api.nuget.org/v3/index.json`）。`dotnet nuget locals all --clear` 後に `dotnet restore` |
| NU1100: Unable to resolve '...' for '...' | 依存関係が対象フレームワークで解決できない、またはソース未構成 | ターゲットフレームワーク互換性・ソース構成を確認 |

出典: 
- Resolve errors and warnings related to assembly references https://learn.microsoft.com/dotnet/csharp/language-reference/compiler-messages/assembly-references
- Nullable reference type warnings https://learn.microsoft.com/dotnet/csharp/language-reference/compiler-messages/nullable-warnings
- NuGet Error NU1101 https://learn.microsoft.com/nuget/reference/errors-and-warnings/nu1101

## 6. フレームワーク

| フレームワーク | プロファイル |
|--------------|-------------|
| ASP.NET Core（MVC / Web API / Minimal API）/ Entity Framework Core / Blazor / ASP.NET WebForms（レガシー） | [frameworks/dotnet.md](frameworks/dotnet.md) |
