---
name: code-review-architecture
description: |
  アーキテクチャ観点（システム構造・技術選定・データ層）でコード変更をレビューする観点別スキル。
  内部で architect / dba の2エージェントを並列起動する（DB変更がない場合は dba を省略可）。

  以下の場面で使用する:
  - 「アーキテクチャ観点でレビューして」「設計影響を確認して」と言われた場合
  - 「DB スキーマ変更 / マイグレーションをレビューして」と言われた場合
  - 大規模リファクタリング・コンポーネント境界の変更時
  - code-review オーケストレーターから委譲された場合（標準モードのみ）
allowed-tools:
  - Read
  - Grep
  - Glob
  - Agent(architect)
  - Agent(dba)
  - Bash(git *)
---

> **推奨依存の MCP（任意）**: `microsoft-docs`（`claude-plugins-official`）プラグインが導入されている環境では、そのプラグインが提供する Microsoft Learn ドキュメント検索・取得 MCP ツールを .NET 一次情報照合に利用できる（`${CLAUDE_PLUGIN_ROOT}/references/frameworks/dotnet.md` セクション 4.1）。MCP ツール名は導入環境で解決されるため `allowed-tools` に固定列挙せず、利用可能な場合のみ用いる（未導入時は照合をスキップ）。

# code-review-architecture スキル

## 責務

コード変更を **アーキテクチャ観点・データ層観点** からレビューする。観点は2つ:

## トリガー条件

- code-review オーケストレーターから Skill ツール経由で委譲された場合（標準モード）
- 「アーキテクチャ観点でレビューして」「設計影響を確認して」「DB スキーマ変更をレビューして」と言われた場合

## 前提

- レビュー対象の差分・プロジェクト規約サマリが引数で渡されていること
- architect / dba エージェント定義が `${CLAUDE_PLUGIN_ROOT}/agents/` に存在すること

| 観点 | 担当エージェント | 責務 |
|------|----------------|------|
| アーキテクチャ全体整合性 | architect | システム設計・技術選定・拡張性・技術的負債・コンポーネント境界・依存方向 |
| データ層 | dba | DB スキーマ・SQL 最適化・マイグレーション安全性・インデックス・データ整合性 |

## 動的に省略可（責務はオーケストレーター）

> **注意**: 本スキルが呼ばれたら **必ず両エージェントを起動する**（DB変更なしの場合のみ dba を内部で省略）。本スキル自体を呼ぶか否かの判断は **`code-review` オーケストレーター側** で行う。本スキル単独で「呼ばれたが何もしない」という判断はしない。

| エージェント | 内部省略条件（本スキル内で判定） |
|------------|---------|
| architect | 常に起動 |
| dba | SQL / DB スキーマ / マイグレーション変更が一切ない場合のみ内部で省略 |

オーケストレーター側で本スキル自体を省略する条件:
- アーキテクチャに影響しない単純変更（コメント追記・タイプミス修正等）のみ かつ DB 変更なし

## 実行モード判定

観点別スキルは **起動形態（委譲 / 単独）** を判定する。対話 / 非対話の UI モード判定（`AskUserQuestion`）はオーケストレーター（`code-review`）の責務であり、本スキルは行わない。

| 入力 | 起動形態 | 動作 |
|-----|---------|------|
| `code-review` から Skill 委譲（引数に規約サマリ / `language-profiles` 等） | 委譲 | モード・スコープ・言語プロファイルは確定済みとして受領し、非対話で観点別レビューを実行。結果は中間レポート（内部データ）として返す |
| ユーザーが直接起動（「アーキテクチャ観点でレビューして」等） | 単独 | 対象差分・言語/FW を自己検出（O10）し、`progress.md` を自スキルで作成（O8）。標準/簡易モードの確認は行わない |

## 入力

| 引数 | 内容 |
|------|------|
| スコープ | レビュー対象（差分・PR・ファイル一覧） |
| プロジェクト規約サマリ | `CLAUDE.md` / `.claude/rules/` / `docs/` 配下の設計ドキュメント |
| 言語プロファイル | `language-profiles=<...>` 形式。検出言語・FW の観点プロファイルパス一覧（`${CLAUDE_PLUGIN_ROOT}/references/languages/` / `frameworks/`）。未受領時は `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` で自己検出する（O10） |
| システム全体像 | 既存アーキテクチャ・技術スタック・主要コンポーネントの構成（任意） |
| DB 情報 | DB 種別（SQL Server/PostgreSQL/MySQL等）・テーブル規模・想定データ量・アクセスパターン（DB変更ありの場合） |

## 実行フロー

1. 引数を解釈し、対象差分・関連ファイル・DB マイグレーション SQL を確定
1.5. `language-profiles` の適用観点プロファイルを確認し（未受領時は `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` で自己検出）、各エージェントのプロンプトに言語プロファイル参照指示（`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション 4.5 のテンプレート）を含める（O10）
1.6. （.NET 差分検出時・任意）**推奨依存 `microsoft-docs`** MCP が利用可能なら、使用 .NET / ASP.NET Core / EF Core API の非推奨・破壊的変更を learn.microsoft.com で照合する（`${CLAUDE_PLUGIN_ROOT}/references/frameworks/dotnet.md` セクション 4.1）。未解決の環境ではスキップし静的観点のみで評価する（「未照合」を「問題なし」と書かない）
2. DB 変更があるか判定し、`dba` の起動可否を決定
3. 該当エージェントを **1メッセージ内で並列起動**:
   ```
   Agent({ subagent_type: "architect", ... })
   Agent({ subagent_type: "dba",       ... })   # DB 変更あり時のみ
   ```
4. 各エージェントの結果を **観点別中間レポート** にまとめて返却

## 参照

本観点別スキルが参照する共通リファレンスは **`${CLAUDE_PLUGIN_ROOT}/references/common-references.md`** に集約済み（プラグイン内 SSOT）。
ルール ID 体系（Universal U1〜U16 + Observation O1〜O10）は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` を参照。

## 達成チェックリスト

- `${CLAUDE_SKILL_DIR}/references/checklist.md` — 中間レポート返却前のルール達成チェック

> 統合サマリの最終フォーマット・Verdict 判定はオーケストレーター（`code-review`）の責務。本スキルは中間レポート（後述「出力フォーマット」セクションの形式）を返すのみ。

## 出力フォーマット

```markdown
## アーキテクチャ観点レビュー結果

### architect
- 検出した設計上の問題: ...
- 技術的負債リスク: ...
- コンポーネント境界・依存方向に関する指摘: ...

### dba（DB変更あり時のみ）
- スキーマ変更の安全性評価: ...
- マイグレーション戦略の指摘: ...
- インデックス・クエリ最適化提案: ...
```

## 重要な制約

- Write ツールによるレビュー対象ソースコードの変更は行わない
- 統合サマリの最終フォーマット・Verdict 判定はオーケストレーター（`code-review`）の責務であり、本スキルは中間レポートを返すのみ

## 責務外

進捗管理（U5・複数エージェント並列起動時の `progress.md` 維持）と、自スキル外と判断した指摘の他観点別スキルへの振分けルールは、**`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション4 / セクション5** に集約済み（共通化済み）。
