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

> 3.x 本文は観点別 details に分離済み。**各 3.x の【担当】に対応する details のみ Read** すること（重要度表(節4)・動的検証(節6)は本 hub に残置）:
> - [`csharp-impl.md`](csharp-impl.md) … 3.1 3.2 3.3 3.4 3.5 3.6 3.8
> - [`csharp-security.md`](csharp-security.md) … 3.7

### 3.1 正確性・堅牢性【担当: implementation-engineer】

> → 本文は [`csharp-impl.md`](csharp-impl.md)（3.1）

### 3.2 エラー処理・silent-failure【担当: implementation-engineer】

> → 本文は [`csharp-impl.md`](csharp-impl.md)（3.2）

### 3.3 型・null 安全【担当: implementation-engineer】

> → 本文は [`csharp-impl.md`](csharp-impl.md)（3.3）

### 3.4 非同期・並行処理【担当: implementation-engineer / performance-reviewer】

> → 本文は [`csharp-impl.md`](csharp-impl.md)（3.4）

### 3.5 命名・スタイル【担当: implementation-engineer / linter-static-analysis】

> → 本文は [`csharp-impl.md`](csharp-impl.md)（3.5）

### 3.6 パフォーマンス【担当: performance-reviewer】

> → 本文は [`csharp-impl.md`](csharp-impl.md)（3.6）

### 3.7 セキュリティ【担当: security-engineer】

> → 本文は [`csharp-security.md`](csharp-security.md)（3.7）

### 3.8 コメント・ドキュメント整合【担当: implementation-engineer】

> → 本文は [`csharp-impl.md`](csharp-impl.md)（3.8）

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
