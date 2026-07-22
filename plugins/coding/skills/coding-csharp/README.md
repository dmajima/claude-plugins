# coding-csharp スキル

C# のデファクト規約（Microsoft C# Coding Conventions / .NET Naming Guidelines）・コード構造・主要フレームワーク（ASP.NET Core / EF Core / Blazor / WebForms）の知識を提供する言語スキル。`orchestrator-coding` / `orchestrator-design` からの参照と、単独起動時の軽量実装フローの両方に対応する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキルの動作定義は `SKILL.md` と `references/` を参照してください。

## 導入手順

本スキルは `coding` プラグインに同梱されています。プラグイン本体の導入手順（マーケットプレイス登録・インストール・自動更新）は [プラグイン README](../../README.md) を参照してください。本スキル単体での追加インストールは不要です。

導入後は `orchestrator-coding` / `orchestrator-design` から自動的に参照されるほか、下記「使い方」のトリガーフレーズでユーザが直接起動できます。

## 使い方

このスキルには 2 つの利用モードがある。

### 1. オーケストレーターからの参照（参照モード）

`orchestrator-coding`（実装ワークフロー）や `orchestrator-design`（設計ワークフロー）が C# プロジェクトを検出した際に、本スキルの `references/` を規約・構造の判定基準として参照する。ユーザが直接起動する必要はない。

### 2. 単独起動（単独実行モード）

小規模な C# の実装・修正では、以下のようなフレーズで直接起動する。

| 発話例 | 動作 |
|-------|------|
| 「C# で〜を実装して」 | 規約解決 → 実装 → 検証の軽量フロー |
| 「この C# コードを直して」 | 既存スタイルを維持して修正 |
| 「ASP.NET Core の API を書いて」 | dotnet.md の FW 規約を併用して実装 |

変更が 4 ファイル以上に膨らむ場合は `orchestrator-coding` への切替を提案する。

## 対応フレームワーク

| フレームワーク | 検出マーカー | プロファイル |
|--------------|-------------|-------------|
| ASP.NET Core（MVC / Web API / Minimal API） | `Microsoft.AspNetCore.*` 参照 / `Microsoft.NET.Sdk.Web` | `references/frameworks/dotnet.md` |
| Entity Framework Core | `Microsoft.EntityFrameworkCore.*` 参照 / `DbContext` 派生 | 同上 |
| Blazor | `.razor` / `Microsoft.AspNetCore.Components.*` | 同上 |
| ASP.NET WebForms（レガシー） | `.aspx` / `System.Web` / 旧形式 `*.csproj` | 同上 |

言語横断の ORM 知識（EF Core を含む）は SSOT `../../references/frameworks/orm.md` に集約している。

## カスタマイズ

| やりたいこと | 編集対象 |
|-------------|---------|
| C# のデファクト規約・命名・ツールチェーンを調整 | `references/conventions.md`（本スキルの SSOT） |
| フレームワーク固有規約を追加・修正 | `references/frameworks/dotnet.md` |
| 規約の優先順位ルールを変更 | プラグイン共通 `../../references/conventions-resolution.md` |

## ファイル構成

```text
skills/coding-csharp/
├── SKILL.md                        # スキル定義（本スキルのエントリポイント）
├── README.md                       # 本ファイル（人間向け）
└── references/
    ├── conventions.md              # C# 言語規約の SSOT
    └── frameworks/
        └── dotnet.md               # ASP.NET Core / EF Core / Blazor / WebForms
```
