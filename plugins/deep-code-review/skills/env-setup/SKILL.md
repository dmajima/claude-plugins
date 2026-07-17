---
name: env-setup
description: |
  deep-code-review プラグインが利用する外部依存ツール（Windows 標準以外）のインストール・更新・存在確認を集約するスキル。
  PR レビュー・LSP・動的検証で必要となる gh / az CLI / azure-devops 拡張 / csharp-ls / typescript-language-server / Node.js / Python / .NET SDK 等を扱う。

  以下の場面で使用する:
  - 「環境構築して」「必要なツールをインストールして」と言われた場合
  - 他スキル（pr-review / code-review-* 等）が必要ツールの不在を検知して呼び出した場合
  - 「gh / az / csharp-ls / typescript-language-server がない」とエラーが出た場合

  本スキルは **Windows 標準以外の外部依存ツール全て** のインストール窓口。
  各スキルは個別にインストールせず、必要時に本スキルへ依頼する設計。
allowed-tools:
  - Read
  - Grep
  - Glob
  - AskUserQuestion
  - Bash(which *)
  - Bash(winget *)
  - Bash(npm *)
  - Bash(dotnet *)
  - Bash(pip *)
  - Bash(az *)
  - Bash(gh *)
  - Bash(node *)
  - Bash(python *)
  - Bash(py *)
  - Bash(jq *)
---

# env-setup スキル

## 責務

deep-code-review プラグインおよび配下のスキル群が利用する **Windows 標準以外の外部依存ツール** のインストール・存在確認・バージョン確認を**一箇所に集約する**。

## トリガー条件

- 「環境構築して」「必要なツールをインストールして」「gh をインストールして」と言われた場合
- 他スキル（pr-review / code-review-* 等）が必要ツールの不在を検知して呼び出した場合
- 「gh / az / csharp-ls がない」等のエラーが報告された場合

## 前提

- Windows 環境であること（winget を利用するため）
- 管理者権限が必要な場合はユーザーが手動で昇格すること

各スキル（`pr-review` / `code-review-*` 等）は外部ツールが必要な際に本スキルに **依頼する** だけで済む。各スキルが個別のインストール手順を保持することは禁止。

## 管理対象ツール一覧

| ツール | 用途 | インストール方法 | 確認コマンド |
|--------|------|----------------|-------------|
| `gh` | GitHub CLI（PRレビュー・API） | `winget install --id GitHub.cli --accept-package-agreements --accept-source-agreements` | `gh --version` |
| `az` | Azure CLI（Azure DevOps Git PR） | `winget install --id Microsoft.AzureCLI --accept-package-agreements --accept-source-agreements` | `az --version` |
| `azure-devops 拡張` | Azure DevOps Git PR / ボード操作（**MS アカウントで動作、PAT 不要**） | `az extension add --name azure-devops` | `az devops --help` |
| `jq` | コメント本文・JSON body の安全な構築（コマンドインジェクション対策） | `winget install --id jqlang.jq --accept-package-agreements --accept-source-agreements` | `jq --version` |
| `csharp-ls` | C# Language Server（csharp-lsp プラグイン依存） | `dotnet tool install --global csharp-ls` | `csharp-ls --version` |
| `typescript-language-server` | TS/JS Language Server（typescript-lsp プラグイン依存） | `npm install --global typescript-language-server typescript` | `typescript-language-server --version` |
| `node` | Node.js（npm/eslint/prettier 等のベース） | `winget install --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements` | `node --version` |
| `python` | Python 3.10+（hook・スクリプト） | `winget install --id Python.Python.3.12 --accept-package-agreements --accept-source-agreements` | `python --version` |
| `dotnet` | .NET SDK 8.0+（dotnet build / test / pack） | `winget install --id Microsoft.DotNet.SDK.8 --accept-package-agreements --accept-source-agreements` | `dotnet --version` |
| `pwsh` | PowerShell 7+（pwsh ベースの CI スクリプト等） | `winget install --id Microsoft.PowerShell --accept-package-agreements --accept-source-agreements` | `pwsh --version` |
| `curl` | TFS Server NTLM 認証時に必須（Windows 10/11 標準で同梱） | Windows 標準（インストール不要） | `curl --version` |

> 上記以外のツールが必要になった場合は `${CLAUDE_SKILL_DIR}/references/tools-catalog.md` に追加してから本スキルから扱うこと（個別スキル側で勝手にインストールしない）。

## 実行モード判定

本スキルは **確認モード（既定）/ インストールモード / 委譲（他スキルからの依頼）** の3系統で動作する。他スキル（`pr-review` / `code-review-*` 等）からの委譲呼び出し時は、引数（`verify` / `install`・対象ツール）に従い非対話で実行する。

### 1. 確認モード（既定）

ユーザーから明確な「インストールして」指示がない場合は、まず **存在確認** のみを行う。

```bash
# 全ツール一括確認
where gh az node npm python dotnet pwsh
```

存在しないツールがあれば、ユーザーに **インストール可否を確認** してから実行する。

### 2. インストールモード

ユーザーが「インストールして」「セットアップして」と明示した場合、または他スキルからインストール依頼を受けた場合のみ、対象ツールを順にインストールする。

#### Windows でのインストール優先順位

1. **`winget`**（Windows 標準パッケージマネージャ・最優先）
2. ツール固有のサブコマンド（`dotnet tool install` / `npm install -g` / `az extension add`）
3. 上記が使えない場合のみ MSI / EXE インストーラ（事前にユーザー確認）

#### 管理者権限が必要な場合

`winget` でグローバルインストールする際に管理者昇格が必要な場合がある。
**自動で昇格しない**。代わりにユーザーに以下を表示する:

```
> 以下のコマンドを管理者 PowerShell で実行してください:
> winget install --id <PackageId> --accept-package-agreements --accept-source-agreements
```

## 実行フロー

1. **依頼内容の解釈**: 確認のみか、インストール込みか、対象ツールは何か
2. **存在確認**: `where <tool>` で確認
3. **不足ツールの提示**: 一覧をユーザーに見せる
4. **インストール承認の取得**: AskUserQuestion で確認（不足ツールを一覧で提示し、まとめて承認を取る）
5. **インストール実行**: 上記優先順位に従ってインストール
6. **再確認**: インストール後にバージョンを確認し、結果を報告

## 入力（呼び出し時の引数）

| 引数 | 例 | 内容 |
|------|------|------|
| 操作 | `verify` / `install` | 確認のみ or インストール込み |
| 対象ツール | `gh,az,azure-devops` | カンマ区切り、`all` も可 |
| 呼び出し元 | `pr-review` | 依頼元スキル名（任意・ログ用） |

## 出力フォーマット

```markdown
## env-setup 結果

### 既にインストール済み
- gh 2.45.0
- az 2.60.0

### インストール実行
- azure-devops 拡張 → 成功
- csharp-ls 0.13.0 → 成功

### インストール失敗・要対応
- typescript-language-server: npm が見つからない（先に Node.js を入れる必要あり）

### 推奨アクション
- ユーザーが「Node.js もインストールして」と指示すれば続行可能
```

## 参照

- `${CLAUDE_SKILL_DIR}/references/tools-catalog.md` — 管理対象ツールの詳細カタログ（追加・更新時はここを編集）
- `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` — 本スキルが満たすべきルール ID 体系（Universal + Environment E1〜E6）

## 達成チェックリスト

- `${CLAUDE_SKILL_DIR}/references/checklist.md` — 完了報告返却前のルール達成チェック（Universal + Environment 全項目）

## 責務外

- ツールの利用方法・運用手順（各スキル側のドキュメントで管理）
- プロジェクト固有の依存関係（`dotnet restore` / `npm install` 等）—各リポジトリで実施
- 認証情報の管理（`gh auth login` / `az login` / credentials-manager プラグインでの登録等はユーザーが実施。外部接続時の取得は connector が解決）
- ツールのアップデート（明示的な依頼があった時のみ実行）

## 重要な制約

- 管理者権限への自動昇格
- ユーザー承認なしでのインストール実行
- 個別スキル内に独自のインストール手順を持つこと（必ず本スキル経由で集約する）
