# Case 01: 単独実行モードの基本フロー

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「C# でこの日付処理ユーティリティにメソッドを追加して」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | SDK スタイルの .NET プロジェクト（`*.csproj` + `.editorconfig` あり）。対象は `DateUtils.cs` の 1 クラス。変更見込み 1〜2 ファイル |

## 期待動作

単独実行モードの軽量フロー（規約解決 → FW 確認 → 実装 → 検証 → 報告）を実施する。

### 手順 1: 規約解決
- 規約優先順位の SSOT（`conventions-resolution.md`）に従い、プロジェクト独自規約（`.editorconfig` / `Directory.Build.props` / `stylecop.json` / `CLAUDE.md` / 既存慣習）を走査する
- 独自規約がない項目は `references/conventions.md` のデファクト規約で補完する（メソッドは PascalCase、非同期メソッドは `Async` サフィックス、private フィールドは `_camelCase`、Allman ブレース、スペース 4）
- 規約の矛盾・実装方針の拮抗があれば `AskUserQuestion` で確認する（対話モード）。本ケースは方針が自明なため確認なしで進む

### 手順 2: FW 確認
- `*.csproj` の参照に `Microsoft.AspNetCore.*` / `Microsoft.EntityFrameworkCore.*` が無く、純粋なユーティリティのため FW プロファイル（`references/frameworks/dotnet.md`）は非該当

### 手順 3: 実装
- 解決した規約に従い `DateUtils.cs` にメソッドを追加する
- 既存ファイルの編集のため、周辺コードのスタイル・エンコーディング・改行コードを維持する

### 手順 4: 検証
- 規約解決で確定したツールチェーンで検証する（`dotnet build`、`.editorconfig` 準拠は `dotnet format --verify-no-changes`、テストがあれば `dotnet test`）
- 実行不能な検証は SKIPPED として報告する

### 手順 5: 報告
- 変更ファイル・適用規約の根拠（`.editorconfig` の該当設定 or デファクト）・検証結果を報告する
- 変更見込みが 4 ファイル未満のため `orchestrator-coding` への切替提案は行わない

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `DateUtils.cs`（必要に応じてテスト 1 ファイル） |
| 標準出力（要約） | 追加メソッド・適用規約の根拠・`dotnet build` / `dotnet format` の結果 |
| 終了状態 | 成功（単独実行モードで完結） |

## 分岐の根拠

このケースが分岐するトリガーは タスク規模が小さく（変更 1〜2 ファイル）言語が C# で明確 である。
このため `orchestrator-coding` の 6 フェーズ統括ではなく、言語スキル単独の軽量フローで処理する。
境界: フェーズ統括・複数言語の併用・設計判断が必要なら `orchestrator-coding` に委ねる。

## 関連ケース

- `case-02_scope-escalation.md`（スコープが 4 ファイル以上に膨らむ場合との対比）
