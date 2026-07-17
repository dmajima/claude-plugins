# .NET フレームワークレビュー観点プロファイル

C# / .NET の主要フレームワークが関与する変更差分をレビューする際の FW 固有観点。言語共通観点は `${CLAUDE_PLUGIN_ROOT}/references/languages/csharp.md` を先に適用し、本ファイルはそれに上乗せする。プロジェクト独自規約が存在する場合はそちらを優先する。

## 1. 対象と検出条件

差分に以下のマーカーが含まれる場合、該当 FW のレビュー観点を適用する。複数該当時は併用する（例: ASP.NET Core + EF Core、Blazor Web App + EF Core）。

| フレームワーク | 検出マーカー（csproj / パッケージ / ファイル） |
|--------------|----------------------------------------|
| ASP.NET Core（MVC / Web API / Minimal API） | `*.csproj` の `<Project Sdk="Microsoft.NET.Sdk.Web">` / `Microsoft.AspNetCore.*` の `<PackageReference>` / `<FrameworkReference Include="Microsoft.AspNetCore.App" />`、`Program.cs` の `WebApplication.CreateBuilder(args)` |
| Entity Framework Core | `Microsoft.EntityFrameworkCore.*`（`.SqlServer` / `.Npgsql` / `.Sqlite` 等プロバイダ）の参照、`DbContext` 派生クラス、`Migrations/` フォルダ |
| Blazor | `.razor` ファイル、`Microsoft.AspNetCore.Components.*` 参照。WebAssembly は `Microsoft.AspNetCore.Components.WebAssembly.*` |
| ASP.NET WebForms（レガシー / .NET Framework） | `.aspx` / `.ascx` / `.master`、`System.Web` 参照、旧形式 csproj（`<TargetFrameworkVersion>v4.x</...>`）、`Web.config`、`packages.config` |

**EF Core 観点の正典は本ファイル節 2.2**（N+1・`AsNoTracking`・生 SQL・トランザクション・マイグレーションを含む）。`${CLAUDE_PLUGIN_ROOT}/references/frameworks/orm.md` 節 2.3 は本ファイルを正典として参照し、ORM 横断比較の追加観点（ChangeTracker 肥大化・cartesian explosion 等）のみを提供する（片方向参照）。

## 2. FW ごとのレビュー観点

### 2.1 ASP.NET Core（MVC / Web API / Minimal API）

- [ ] **DI ライフタイムの誤り**: Singleton サービスに Scoped / Transient を注入していないか（captive dependency。Singleton が Scoped の `DbContext` を掴み続けるとスレッド安全性・データ整合性が壊れる）【担当: implementation-engineer / architect】
- [ ] **ミドルウェア順序**: `UseRouting → UseAuthentication → UseAuthorization → エンドポイント（MapControllers 等）` の順序が守られているか。認証・認可がエンドポイント実行より後だと保護が効かない【担当: security-engineer / implementation-engineer】
- [ ] **ModelState 検証漏れ**: `[ApiController]` 未使用のコントローラで `ModelState.IsValid` チェックを省略していないか（不正入力がそのまま処理される）【担当: implementation-engineer / security-engineer】
- [ ] **モデルバインディングの過剰投稿（over-posting）**: リクエストを EF エンティティへ直接バインドし、ユーザーが変更すべきでないプロパティ（`IsAdmin` / `Price` 等）を上書きできないか → 入力専用 DTO / `[Bind]` 許可リスト / `TryUpdateModel`【担当: security-engineer / implementation-engineer】
- [ ] **`[Authorize]` 属性の付け漏れ**: 認可の既定拒否（deny-by-default）が担保されているか。個別アクションに `[Authorize]` を付ける方式は付け漏れリスクが高い。フォールバックポリシー / `RequireAuthorization()` の有無を確認【担当: security-engineer】
- [ ] **Minimal API のパラメータバインディング**: ハンドラ引数のバインディング元（ルート / クエリ / ボディ / DI）が意図通りか。複雑型が誤って body にバインドされていないか、`[FromServices]` / `[FromBody]` 明示の要否【担当: implementation-engineer】
- [ ] **シークレットの直書き**: `appsettings.json` に接続文字列・API キー・パスワードを平文で置いていないか（User Secrets / 環境変数 / Key Vault へ）【担当: security-engineer】
- [ ] **CORS の過剰許可**: `AllowAnyOrigin` + `AllowCredentials` の同時使用、ワイルドカードオリジンなど過度に緩い設定になっていないか【担当: security-engineer】
- [ ] **例外処理・エラー詳細の漏洩**: 本番で開発者例外ページ（`UseDeveloperExceptionPage`）やスタックトレースを露出していないか。`UseExceptionHandler` / `ProblemDetails` で統一しているか【担当: security-engineer / implementation-engineer】
- [ ] **アンチフォージェリ（CSRF）**: 状態変更を伴う MVC / Razor Pages フォームで antiforgery トークン検証を省略していないか（Cookie 認証系で特に重要）【担当: security-engineer】
- [ ] **公開エンドポイントのレート制限 / 入力サイズ上限**: 認証前の公開 API にレート制限・リクエストボディ上限がなく DoS 面が開いていないか【担当: security-engineer / dependency-safety】
- [ ] **`HttpContext` への静的アクセス**: `IHttpContextAccessor` を介さず握った `HttpContext` を非同期処理・バックグラウンドに持ち越していないか（null 参照・スレッド間汚染）【担当: implementation-engineer / architect】
- [ ] コントローラにビジネスロジックを詰め込まず Service 層へ分離しているか。I/O アクションが `async Task<IActionResult>` で非同期 API を `await` しているか【担当: implementation-engineer / architect】
- [ ] **データアクセス方式の統一**: 同一コントローラ / 同一層で生 ADO.NET（`SqlConnection` / `SqlCommand`）と EF Core（`DbContext`）が混在していないか。混在はトランザクション境界・接続管理・保守性の観点で問題（Medium）。既存の一貫した方式に揃える【担当: architect / implementation-engineer】
// NG: Singleton に Scoped の DbContext が捕捉される（captive dependency）
builder.Services.AddSingleton<IOrderCache, OrderCache>(); // 内部で AppDbContext を注入
builder.Services.AddDbContext<AppDbContext>(...);         // 既定は Scoped

// OK: DbContext を必要とするサービスは Scoped、または IServiceScopeFactory で都度解決
builder.Services.AddScoped<IOrderCache, OrderCache>();

// NG: 認可がエンドポイントより後 → 保護が効かない
app.MapControllers();
app.UseAuthentication();
app.UseAuthorization();
// OK: 認証 → 認可 → エンドポイントの順
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
```

### 2.2 Entity Framework Core

- [ ] **N+1 クエリ**: 一覧取得後にループ内で関連へアクセス（遅延読み込み）していないか → `Include()` / `ThenInclude()` でイーガーロード、または必要列のみ射影（`Select`）【担当: performance-reviewer / dba】
- [ ] **読み取り専用での `AsNoTracking()` 欠落**: 更新しない読み取りクエリに変更追跡が付いたままになっていないか（メモリ・CPU オーバーヘッド）【担当: performance-reviewer】
- [ ] **`SaveChanges` の呼び忘れ / 過剰呼び出し**: 変更が永続化されない（呼び忘れ）／ループ内で 1 件ずつ `SaveChanges` を呼びラウンドトリップが激増していないか【担当: implementation-engineer / dba】
- [ ] **トランザクション境界**: 複数 `SaveChanges` にまたがる原子性が必要な処理を `Database.BeginTransaction()` で明示的に囲んでいるか【担当: dba / implementation-engineer】
- [ ] **`IQueryable` のクライアント評価**: DB で評価できないメソッド（C# 独自関数等）を `Where` 内で使い、全件メモリ展開後にフィルタしていないか。`ToList()` / `AsEnumerable()` の位置が早すぎないか【担当: performance-reviewer】
- [ ] **生 SQL（`FromSqlRaw` / `ExecuteSqlRaw`）のパラメタライズ**: 文字列補間で外部入力を埋め込んでいないか → プレースホルダ（`{0}`）/ `FromSqlInterpolated` / パラメータオブジェクトを使う【担当: security-engineer】
- [ ] **マイグレーションの破壊的変更**: 列削除・リネーム・NOT NULL 化を 1 ステップで行っていないか（expand-contract。ローリングデプロイ中の新旧混在に耐えるか）。生成マイグレーションをレビューしたか【担当: dependency-safety / dba】
- [ ] **`DbContext` の並行使用・ライフタイム**: `DbContext` を複数スレッドで共有・長寿命化していないか（Scoped が原則。`Task.WhenAll` で同一 context を並行操作しない）【担当: implementation-engineer】
- [ ] **楽観的並行性制御**: 競合しうる更新に並行性トークン（`[Timestamp]` / `RowVersion` / `IsConcurrencyToken`）を用意し、`DbUpdateConcurrencyException` を処理しているか（read-modify-write のロストアップデート防止）【担当: implementation-engineer / dba】

```csharp
// NG: ループ内で関連を都度ロード（N+1）
var orders = await db.Orders.ToListAsync();
foreach (var o in orders) { var items = o.Items; /* 遅延読み込みで N 回クエリ */ }

// OK: Include でイーガーロード + 読み取り専用は AsNoTracking
var orders = await db.Orders.Include(o => o.Items).AsNoTracking().ToListAsync();
```

### 2.3 Blazor（Server / WebAssembly）

- [ ] **Server / WASM 実行モデル差の誤認**: サーバー専用リソース（DB 接続・ファイル・機密）を WebAssembly（クライアント実行）で参照していないか。レンダーモード前提を固定していないか【担当: implementation-engineer / security-engineer】
- [ ] **`StateHasChanged` の呼び忘れ / 過剰呼び出し**: バックグラウンド更新後の再描画漏れ、または高頻度呼び出しによる過剰再レンダリングがないか。UI スレッド外からは `InvokeAsync(StateHasChanged)` を使うか【担当: implementation-engineer / performance-reviewer】
- [ ] **`IDisposable` / `IAsyncDisposable` コンポーネントの解除漏れ**: タイマー・イベント購読・`DotNetObjectReference` を `Dispose` で解放しているか（Blazor Server はサーキット単位でリークが蓄積）【担当: implementation-engineer】
- [ ] **JS interop の null / 破棄後呼び出し**: プリレンダリング中（`OnAfterRenderAsync` の `firstRender` 前）に JS 呼び出ししていないか、破棄済みコンポーネントから interop していないか【担当: implementation-engineer】
- [ ] **パラメータの直接変更**: `[Parameter]` プロパティを子側で直接書き換えていないか（親の再レンダリングで上書きされ、一方向バインディングの原則に反する）【担当: implementation-engineer】
- [ ] **入力検証（`EditForm`）**: `EditForm` + `DataAnnotationsValidator` を用い、クライアント検証のみに依存してサーバー側検証を欠いていないか【担当: implementation-engineer / security-engineer】
- [ ] **エラー境界（`ErrorBoundary`）**: 未処理例外で Blazor Server のサーキットが切断されないよう `ErrorBoundary` を適切に配置しているか【担当: implementation-engineer】

### 2.4 ASP.NET WebForms（レガシー / .NET Framework）

- [ ] **ViewState 肥大化**: `GridView` 等が大量の ViewState を生成しページを肥大化させていないか。不要箇所は `EnableViewState="false"` / `ViewStateMode="Disabled"` で抑制しているか【担当: performance-reviewer】
- [ ] **PostBack ライフサイクルの取り扱い**: 初期化・データバインドを `if (!IsPostBack) { ... }` で囲んでいるか（ガード漏れはコントロール状態リセット・二重処理の典型原因）【担当: implementation-engineer】
- [ ] **イベントハンドラの重複登録**: `AutoEventWireup="true"` と手動 `+=` 登録の併用でハンドラが二重発火していないか【担当: implementation-engineer】
- [ ] **コントロール ID 依存**: マークアップの `Inherits` / `CodeBehind`（または `CodeFile`）とクラス定義が一致しているか。ID リネーム時の参照切れがないか【担当: implementation-engineer】
- [ ] **ViewState の改ざん防止**: MAC 検証 / `ViewStateUserKey`（CSRF 対策）が無効化されていないか【担当: security-engineer】

## 3. 典型的な指摘パターン（重要度の目安）

| パターン | 重要度の目安 | 根拠 |
|---------|------------|------|
| 生 SQL（`FromSqlRaw`）へのユーザー入力の文字列補間 | Critical | SQL インジェクション |
| `[Authorize]` 付け漏れ・認可ミドルウェア順序誤り | Critical〜High | 認可バイパス（保護されない公開エンドポイント） |
| appsettings へのシークレット直書き（コミット済み） | Critical〜High | 機密漏洩 |
| CORS `AllowAnyOrigin` + `AllowCredentials` | High | 認証付きリソースのクロスオリジン窃取 |
| 状態変更フォームのアンチフォージェリ（CSRF）検証欠落 | High | クロスサイトリクエストフォージェリ |
| 本番でのスタックトレース・例外詳細の露出 | High〜Medium | 内部情報漏洩・攻撃の足がかり |
| DI ライフタイム誤り（Singleton へ Scoped 注入） | High | データ整合性破壊・スレッド安全性違反 |
| 楽観的並行性トークン欠落（競合更新） | High〜Medium | ロストアップデート（データ上書き） |
| マイグレーションの破壊的変更（1 ステップ列削除等） | High | ローリングデプロイ中の障害・データ損失 |
| `SaveChanges` 呼び忘れ | High | 変更が永続化されず機能不全 |
| `DbContext` 並行使用・長寿命化 | High〜Medium | 実行時例外・データ競合 |
| モデルバインディングの過剰投稿（over-posting） | High | 権限昇格・意図しない列改ざん |
| ModelState 検証漏れ | High〜Medium | 不正入力の通過 |
| EF Core N+1（ループ内遅延読み込み） | High〜Medium | 性能崩壊（データ量依存） |
| Blazor の Dispose 漏れ・`StateHasChanged` 誤り | Medium | リーク・UI 不整合（Server で顕在化） |
| WebForms `IsPostBack` ガード漏れ | Medium | 状態リセット・二重処理 |
| `AsNoTracking` 欠落（読み取り専用） | Medium〜Low | オーバーヘッド（大量データで顕在化） |
| ViewState 肥大化 | Medium〜Low | ページ肥大・帯域増（レガシー保守） |

## 4. 動的検証コマンド（FW 固有分のみ）【担当: linter-static-analysis / dba】

汎用のビルド・テスト・フォーマット検証コマンド（`dotnet build` / `dotnet test` / `dotnet format` / `msbuild`）は **`${CLAUDE_PLUGIN_ROOT}/references/languages/csharp.md` セクション 6 が正典**。本セクションは FW 固有コマンドのみを定義する。
対応する Bash 権限が許可されている場合のみ実行（なければ SKIPPED 記録。「未実施」を「問題なし」と書かない）:

| 検証 | コマンド | 判定 |
|------|---------|------|
| マイグレーション差分確認 | `dotnet ef migrations script` | 破壊的 DDL（DROP / ALTER ... NOT NULL）検出時は dba へ回付し Medium〜High |

### 4.1 .NET 一次情報の照合（推奨依存 `microsoft-docs`・任意）

`microsoft-docs`（`claude-plugins-official`）プラグインが提供する **Microsoft Learn ドキュメント検索・取得 MCP ツール**が利用可能な場合、差分で使われている .NET / ASP.NET Core / EF Core の API について、**非推奨（`[Obsolete]` / deprecated）・推奨パターン・バージョン間破壊的変更**を learn.microsoft.com の一次情報で照合し、指摘の根拠として引用する（ドキュメント検索ツールでクエリ→必要に応じて取得ツールで詳細取得。MCP ツール名は導入環境で解決される）。照合対象の典型:

- 使用 API が対象 TFM（Target Framework）で非推奨・削除されていないか
- ASP.NET Core / EF Core のバージョン間破壊的変更（認証ミドルウェア順序・`DbContext` API 変更等）
- 公式の推奨実装（Minimal API のルーティング・オプションパターン等）との乖離

**推奨依存のため任意**: `microsoft-docs` が未解決の環境では本照合をスキップし、静的観点（本ファイル 2〜3 章）のみで評価する（「未照合」を「問題なし」と記載しない）。コードは送信せず、**検索クエリ（API 名・シンボル名）のみ**を送信する。呼び出し元は `code-review-architecture` スキル（.NET 差分検出時）。

## 5. 関連プロファイル参照

| 参照先 | 用途 |
|-------|------|
| `${CLAUDE_PLUGIN_ROOT}/references/languages/csharp.md` | C# 言語共通観点（非同期・null 安全・例外処理・命名）。本ファイルより先に適用 |
| `${CLAUDE_PLUGIN_ROOT}/references/frameworks/orm.md` | EF Core を含む ORM 横断観点（N+1・トランザクション・生 SQL・マイグレーション） |
