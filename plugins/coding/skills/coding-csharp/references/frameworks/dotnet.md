# .NET フレームワークプロファイル

対象言語プロファイル: [../conventions.md](../conventions.md)（言語規約はそちらに従う。本ファイルは FW 固有規約のみ）

本ファイルは C# / .NET の主要フレームワークを扱う。VB.NET を併用するレガシー資産（WebForms 等）についても、コードビハインドの言語差を補足として記載する。

## 1. 検出

| フレームワーク | 検出マーカー |
|--------------|-------------|
| ASP.NET Core（MVC / Web API / Minimal API） | `*.csproj` の `<Project Sdk="Microsoft.NET.Sdk.Web">` または `Microsoft.AspNetCore.*` の `<PackageReference>` / `<FrameworkReference Include="Microsoft.AspNetCore.App" />`。`Program.cs` の `WebApplication.CreateBuilder(args)` |
| Entity Framework Core | `Microsoft.EntityFrameworkCore.*` パッケージ参照（`.SqlServer` / `.Sqlite` / `.Npgsql` 等のプロバイダ）。`DbContext` 派生クラス、`Migrations/` フォルダ |
| Blazor | `.razor` ファイル、`Microsoft.AspNetCore.Components.*` 参照。WebAssembly は `Microsoft.AspNetCore.Components.WebAssembly.*` |
| ASP.NET WebForms（レガシー / .NET Framework） | `.aspx` / `.ascx` / `.master` ファイル、`System.Web` 参照、旧形式 `*.csproj`（`<TargetFrameworkVersion>v4.8</...>`）、`Web.config`、`packages.config` |

複数該当する場合は併用する（例: ASP.NET Core + EF Core、Blazor Web App + EF Core）。

## 2. ASP.NET Core（MVC / Web API / Minimal API）

出典:
- ASP.NET Core fundamentals overview https://learn.microsoft.com/aspnet/core/fundamentals/
- Dependency injection in ASP.NET Core https://learn.microsoft.com/aspnet/core/fundamentals/dependency-injection
- Minimal APIs quick reference https://learn.microsoft.com/aspnet/core/fundamentals/minimal-apis
- Options pattern / DI into controllers https://learn.microsoft.com/aspnet/core/mvc/controllers/dependency-injection

### 2.1 プロジェクト構造・配置規則

- `Program.cs`: アプリのエントリポイント。`WebApplication.CreateBuilder(args)` でサービス（DI コンテナ）を構成し、`builder.Build()` 後にミドルウェアパイプラインを定義する。.NET 6 以降は `Startup` クラスを使わずすべて `Program.cs` に集約するのが既定（`Startup` クラスも引き続き利用可）。
- MVC の標準配置: `Controllers/`（`*Controller.cs`）、`Models/`、`Views/{Controller}/{Action}.cshtml`、`Services/`、`wwwroot/`（静的ファイル）。
- Web API: コントローラは `ControllerBase` を継承し `[ApiController]` を付与。ルーティングは属性ルーティング（`[Route("api/[controller]")]`, `[HttpGet]` 等）。
- 設定: `appsettings.json` を基底に `appsettings.{Environment}.json`（例: `appsettings.Development.json`）で環境別に上書き（階層マージ）。環境変数・コマンドライン引数も構成ソースになる。

### 2.2 FW 固有の命名・実装規約

- コントローラ名は `PascalCase` + `Controller` サフィックス（`OrdersController`）。アクションメソッドは PascalCase。
- DI 登録は `builder.Services` に対して行い、ライフタイムを明示する:
  - `AddScoped<T>()`（リクエスト単位）/ `AddSingleton<T>()`（アプリ全体で単一）/ `AddTransient<T>()`（都度生成）。
  - インターフェースと実装を分離して登録: `builder.Services.AddScoped<IOrderService, OrderService>();`
- 依存はコンストラクタインジェクションで受け取る（サービス・コントローラとも）。
- 設定値の取得は **Options パターン**を使う: 設定クラスを定義し `builder.Services.Configure<TSettings>(...)`、利用側で `IOptions<TSettings>` を注入する。コントローラへ `IConfiguration` を直接注入するのは非推奨。
- Minimal API: `app.MapGet("/path", handler)` / `MapPost` / `MapPut` / `MapDelete` でエンドポイントを定義。ハンドラ引数への DI 自動解決に対応。

### 2.3 ツールチェーン

| 用途 | コマンド |
|------|---------|
| scaffold | `dotnet new web`（Minimal）/ `dotnet new webapi` / `dotnet new mvc` / `dotnet new razor` |
| dev（ホットリロード） | `dotnet watch run` |
| run | `dotnet run` |
| build | `dotnet build` |
| test | `dotnet test` |

### 2.4 ベストプラクティス・アンチパターン

- コントローラ/ページモデルは UI 関心事に集中させ、ビジネスロジックはサービス層へ分離する（Controller/Service 分離）。
- I/O を伴うアクションは `async Task<IActionResult>` とし、EF Core 等の非同期 API を `await` する（サーバースレッドをブロックしない）。
- **アンチパターン**: static なグローバル状態への依存（`static cling`）、サービス内での依存クラスの直接 `new`（密結合）。DI で疎結合にする。
- コンストラクタの注入依存が過多なクラスは単一責任違反のサイン。責務を分割する。
- コンテナが生成した `IDisposable` サービスは開発者が明示的に破棄しない（コンテナが破棄する）。

## 3. Entity Framework Core（.NET 統合面のみ）

**EF Core の ORM としての規約（スキーマ・マイグレーション運用・クエリ最適化・N+1 対策・生 SQL の安全な書き方）の正典は SSOT の [orm.md](../../../../references/frameworks/orm.md) 節 3 である**。本節では .NET / ASP.NET Core との統合面のみを扱い、ORM 共通知識は再掲しない。

出典:
- Nullable reference types（EF Core） https://learn.microsoft.com/ef/core/miscellaneous/nullable-reference-types

### 3.1 .NET 統合の要点

- 接続構成は DI 経由の `AddDbContext<AppDbContext>(o => o.UseSqlServer(connectionString))` が ASP.NET Core の標準（`DbContext` は Scoped ライフタイム。長寿命の `DbContext` はスレッドセーフでないため避ける）
- NRT 有効下でエンティティの非 null ナビゲーション/プロパティは `required`（C# 11 以降）、コンストラクタバインディング、または `= null!;`（null 免除演算子）で初期化警告（CS8618）を解消する
- 非同期 API を使う（`ToListAsync()` / `FirstOrDefaultAsync()` / `SaveChangesAsync()`）— 本プロファイル 2 章の async/await 規約と整合させる
- `DbContext` 派生クラスは `*Context` / `*DbContext` サフィックス、`DbSet<T>` プロパティはエンティティの複数形（`Blogs`, `Posts`）が慣例

マイグレーションコマンド（`dotnet ef migrations add` 等）・AsNoTracking・Include による N+1 回避・expand-contract 等は [orm.md](../../../../references/frameworks/orm.md) 節 3 を参照。

## 4. Blazor（Server / WebAssembly）

出典:
- ASP.NET Core Razor components https://learn.microsoft.com/aspnet/core/blazor/components/
- ASP.NET Core Blazor render modes https://learn.microsoft.com/aspnet/core/blazor/components/render-modes

### 4.1 プロジェクト構造・配置規則

- UI は `.razor` ファイル（Razor コンポーネント）で構成する。1 コンポーネント = 1 ファイルが基本。
- 共有 `using` は `_Imports.razor` に集約する（`Components/_Imports.razor` 等）。
- ルーティング可能なページは先頭に `@page "/route"` ディレクティブを持つ。
- `.NET 8` 以降の Blazor Web App は **レンダーモード**でホスティングモデルを決める（Blazor Server / WebAssembly の二分から移行）。

### 4.2 FW 固有の命名・実装規約

- コンポーネント名・ファイル名は `PascalCase`（`Counter.razor`）。コンポーネントは型名として参照される。
- パラメータは `[Parameter] public T Name { get; set; }`（PascalCase のプロパティ）。
- ロジックは `@code { ... }` ブロックまたは分離コードビハインド（`Counter.razor.cs` の partial class）に書く。
- レンダーモードの指定（.NET 8+）: コンポーネントインスタンスに `<Dialog @rendermode="InteractiveServer" />`、または定義側に `@rendermode InteractiveServer`。利用可能なモード:
  - `Static Server`（静的 SSR・非対話）/ `InteractiveServer`（Blazor Server・対話）/ `InteractiveWebAssembly`（CSR・対話）/ `InteractiveAuto`（初回 Server → 以降 WebAssembly）。
- ライフサイクルメソッド: `OnInitialized` / `OnInitializedAsync`、`OnParametersSet`、`OnAfterRender(bool firstRender)` 等。

### 4.3 ツールチェーン

| 用途 | コマンド |
|------|---------|
| scaffold | `dotnet new blazor`（Blazor Web App）/ `dotnet new blazorwasm`（WebAssembly スタンドアロン） |
| dev | `dotnet watch run` |
| build | `dotnet build` |
| publish | `dotnet publish` |

### 4.4 ベストプラクティス・アンチパターン

- コンポーネントは特定のレンダーモード/ホスティングモデルに実装を結合させない。サーバー/クライアントどちらで動くかを仮定せず、静的レンダリング時も破綻しないよう設計する（出典: render modes ドキュメントの component authors 向けガイダンス）。
- DI はコンポーネントで `@inject T Name` または `[Inject]` 属性で受け取る。
- WebAssembly ではライブラリのトリミング（trimming）でコンポーネントが除去されうるため、直接参照されないプリレンダリング対象は `DynamicDependency` 等で保持する。

## 5. ASP.NET WebForms（レガシー / .NET Framework）

出典:
- Page Class（System.Web.UI, .NET Framework 4.8.1） https://learn.microsoft.com/dotnet/api/system.web.ui.page
- Architecture comparison of ASP.NET Web Forms and Blazor https://learn.microsoft.com/dotnet/architecture/blazor-for-web-forms-developers/architecture-comparison
- The ASP.NET 2.0 Page Model https://learn.microsoft.com/aspnet/web-forms/overview/moving-to-aspnet-20/the-asp-net-2-0-page-model

WebForms は .NET Framework 専用（.NET Core 以降に移植されていない）。保守対象として扱う（WebForms + VB.NET/C# の既存資産を含む）。

### 5.1 プロジェクト構造・配置規則

- ページ（`.aspx`）= マークアップ + サーバーコントロール。`System.Web.UI.Page` を基底とする（実行時にコンパイルされキャッシュされる）。
- ユーザーコントロール（`.ascx`）= 再利用可能な UI 部品。`UserControl`（`System.Web.UI.UserControl`）を基底とする。
- マスターページ（`.master`）= 共通レイアウト。コンテンツページから `@MasterType` ディレクティブで型付き `Master` プロパティを取得できる。
- **コードビハインド**: マークアップと同じ基底名 + 言語拡張子（`.aspx.cs` / `.aspx.vb`、`.ascx.cs` / `.ascx.vb`）。`partial class` として `Page`（または `UserControl`）を継承し、マークアップ側の自動生成 partial クラスと対になる（コントロールをフィールド宣言せず参照できるのはこのため）。
- 設定は `Web.config`（階層化: アプリルート + サブディレクトリ）、パッケージは `packages.config`（旧 NuGet 形式）。

### 5.2 FW 固有の命名・実装規約

- **`@Page` ディレクティブ**でコードビハインドを紐づける（`Inherits` 属性でクラス名を指定）:
  - **Web Application Project（WAP、事前コンパイル）**: `CodeBehind` 属性を使う。例: `<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="Default.aspx.cs" Inherits="WebApplication1._Default" %>`。商用パッケージ製品は通常 WAP 構成。
  - **Web Site Project（実行時コンパイル）**: `CodeFile` 属性を使う。例: `CodeFile="Default.aspx.cs" Inherits="_Default"`。
- **サーバーコントロール**: `asp:` プレフィクス + `runat="server"` + `ID` を持つ（例: `<asp:TextBox ID="MyTextBox" runat="server" />`）。`ID` でコードビハインドから参照する。
- **ViewState**: コントロールの状態はポストバック間で `__VIEWSTATE` という hidden form field にシリアライズされ保持される（`<form runat="server">` がある場合のみ）。プログラムで変更した状態を postback 越しに記憶する仕組み。
- **ポストバック**: 多くのコントロールは自身を表示した同一ページへ post-back する。`Page.IsPostBack` プロパティで初回表示かポストバックかを判定する。`Page_Load(object sender, EventArgs e)` が主要な処理起点（`AutoEventWireup="true"` でイベント自動接続）。

### 5.3 ツールチェーン

| 用途 | コマンド |
|------|---------|
| ビルド | `msbuild <Project>.csproj`（または Visual Studio） |
| パッケージ復元 | `nuget restore <Solution>.sln`（`packages.config` 形式） |
| 実行 | IIS / IIS Express にデプロイ（`dotnet run` は非対応） |
| テスト | MSTest / NUnit（`vstest.console.exe` 経由等） |

### 5.4 ベストプラクティス・アンチパターン（レガシー保守の注意点）

- **ページライフサイクルの理解が必須**: `PreInit → Init → InitComplete → PreLoad → Load → （コントロールイベント）→ PreRender → Unload`。状態を読むタイミングを誤ると ViewState 適用前後で値が上書きされる（例: `PreInit` では ViewState 未適用のためコントロールプロパティ変更が後段で上書きされる）。
- **`IsPostBack` 判定**: 初期化処理（データバインド等）は `if (!IsPostBack) { ... }` で囲み、ポストバック毎の再実行を防ぐ。囲み忘れはコントロール状態の意図しないリセット・二重処理の典型原因。
- **ViewState 肥大化**: `GridView` 等のデータコントロールは大量の ViewState を生成しページを肥大化させる。不要なコントロールは `EnableViewState="false"` / `ViewStateMode="Disabled"` で抑制する（`ViewStateMode` は `EnableViewState="true"` の場合のみ有効）。
- **コードビハインド対応関係**: `.aspx` の `Inherits` とコードビハインドの名前空間 + クラス名が一致している必要がある。移設・リネーム時はマークアップの `Inherits` / `CodeBehind`（または `CodeFile`）とクラス定義の両方を揃える。不一致は実行時エラー（型解決失敗）の原因。
- **言語混在（VB.NET / C#）**: コードビハインドはページ単位で言語が決まる（`.aspx.vb` か `.aspx.cs`）。partial class・コードビハインドモデルは C# / VB.NET のみ対応。プロジェクト内で両言語が混在する場合はコンパイル単位（アセンブリ）の分離に注意する。
