# 管理対象ツールカタログ

`env-setup` スキルが管理する **Windows 標準以外の外部依存ツール** の詳細カタログ。
新規ツールを追加する場合は、必ずこのファイルに登録してから `SKILL.md` の管理対象一覧にも追記する。

---

## 0. ツールカテゴリ分類（責務範囲の明示）

`env-setup` が管理するツールは、**deep-code-review プラグインから見た役割** で以下のカテゴリに分類する。プラグインの責務範囲を明確化し、将来 `env-setup` を独立プラグイン化する際の境界を予め定める。

| カテゴリ | 役割 | 該当ツール | 利用スキル |
|---------|------|----------|----------|
| **A: pr-review 必須** | PR I/O・REST API 操作に必須 | `gh` / `az` / `azure-devops` 拡張 / `jq` / `curl` | `pr-review` |
| **B: LSP（依存プラグイン由来）** | 観点別レビューでの正確な解析。**実体は deep-code-review プラグイン直下の dependencies が要求するため、本来は依存プラグイン側の責務** | `csharp-ls` / `typescript-language-server` | `code-review-implementation` / `code-review-architecture` |
| **C: 動的検証用ランタイム** | コードレビュー中のスポット動作確認・サンドボックス実行用。deep-code-review プラグインの責務範囲外であり、利用は **任意** | `node` / `python` / `dotnet` / `pwsh` | （任意・ユーザー判断） |

### カテゴリ別管理方針

- **カテゴリ A**: 不在時は `pr-review` 起動時に自動検出 → 必要なら `env-setup` を呼び出してインストール（必須）
- **カテゴリ B**: 観点別スキル起動時に自動検出。不在でも警告のみで処理は継続（LSP 不在時はフォールバック）。**将来的には依存プラグイン（`csharp-lsp` / `typescript-lsp`）側で管理する形が理想**
- **カテゴリ C**: 自動インストールしない。ユーザーが必要と判断した場合のみ手動でセットアップを依頼

### 将来の独立プラグイン化ロードマップ（将来の実体分離を計画）

#### 現状（責務再定義済み）

`env-setup` は短期的には deep-code-review プラグイン内に留める。**現状は責務範囲を明文化し、各カテゴリの管理方針を確定済み**:

1. **カテゴリ A（pr-review 必須）**: `env-setup` の **一次責務**。`gh` / `az` / `azure-devops` 拡張 / `jq` / `curl` のインストール・存在確認は引き続き本スキルが担当
2. **カテゴリ B（LSP / 依存プラグイン由来）**: **依存プラグイン側で管理されるべき責務**だが、現状は `csharp-lsp` / `typescript-lsp` プラグイン側にバイナリインストール機能がないため、`env-setup` が **フォールバック** として提供。理想構造への移行は依存プラグイン側の対応待ち
3. **カテゴリ C（動的検証用ランタイム）**: **deep-code-review プラグインの責務範囲外**。明示的なユーザー要求があった場合のみ自動セットアップ。**将来独立プラグイン `tooling-installer`（仮）に分離予定**

#### 将来（実体分離）

| 項目 | 計画 |
|------|------|
| `tooling-installer` プラグイン新設 | カテゴリ C のツール（`.NET SDK` / `Node.js` / `Python` / `PowerShell`）のインストール責務を独立プラグインに分離 |
| `env-setup` の縮小 | カテゴリ A のみを残し、カテゴリ B はフォールバック実装を維持しつつ依存プラグイン側へ移譲を促進 |
| 旧依存スキルへの影響 | code-review-implementation 等が `tooling-installer` を `dependencies` に追加し、環境構築フローはそのまま動作 |

これにより deep-code-review プラグインの責務超過を完全に解消する。

---

## 1. 必須ツール（deep-code-review プラグインのコア機能で使用）

> **カテゴリ A**（pr-review 必須）に該当。

### 1.1 GitHub CLI（gh）

| 項目 | 内容 |
|------|------|
| 用途 | GitHub API 操作（PR取得、コメント追加、レビューステータス管理） |
| 利用スキル | `pr-review` |
| インストール | `winget install --id GitHub.cli --accept-package-agreements --accept-source-agreements` |
| 確認 | `gh --version` |
| 認証 | `gh auth login`（ユーザーが手動実行） |
| 補足 | OAuth または PAT 経由で認証。プライベートリポジトリには `repo` スコープ必要 |

### 1.2 Azure CLI（az）

| 項目 | 内容 |
|------|------|
| 用途 | Azure DevOps Git PR 操作（azure-devops 拡張経由）、Azure リソース操作 |
| 利用スキル | `pr-review` |
| インストール | `winget install --id Microsoft.AzureCLI --accept-package-agreements --accept-source-agreements` |
| 確認 | `az --version` |
| 認証 | `az login` または PAT を `AZURE_DEVOPS_EXT_PAT` 環境変数で設定 |
| 補足 | TFS / Azure DevOps Server（オンプレ）にも対応。エンドポイント指定が必要 |

### 1.3 azure-devops 拡張

| 項目 | 内容 |
|------|------|
| 用途 | Azure DevOps の Git PR / ボード / パイプライン操作 |
| 利用スキル | `pr-review` |
| インストール | `az extension add --name azure-devops` |
| 確認 | `az devops --help` |
| 前提 | `az` CLI 必須 |
| 認証 | **クラウド Azure DevOps**: MS アカウント（`az login`）最優先・PAT は CI/CD 用。**オンプレ TFS Server**: az 拡張は **非対応**（NTLM 経由・curl --ntlm 必須） |
| 補足 | `az repos pr list` / `az repos pr show` / `az repos pr update` 等で **クラウド** Azure DevOps Git PR を操作。**オンプレ TFS では使えない**ため curl --ntlm + REST API で代替（`pr-review/references/azure-devops-tfs-ntlm.md` 参照） |

### 1.3.1 オンプレ TFS Server 利用時の認証（NTLM 推奨）

オンプレ TFS Server（`tfs.<company>.com` 等）に対しては、**既存の Windows ドメインアカウントによる NTLM 認証** が動作する。

| 項目 | 内容 |
|------|------|
| 用途 | オンプレ TFS の REST API（PR 一覧・スレッド・コメント追加・ステータス更新） |
| 利用方法 | `curl --ntlm --netrc-file <file>` 経由 |
| 認証情報の保存 | **credentials-manager プラグイン経由**で `tfs-password` エントリ（`auth_method: "ntlm:<username>"`、`urls: ["https://<host>/*"]`、`domains: ["<host>"]`）を登録（標準ストア `.claude/.local/plugins/credentials-manager/credentials.json`。connector が解決） |
| 安全性 | `.netrc` 一時ファイル経由でコマンドライン引数漏洩を防ぐ。`mktemp` + `chmod 600` + `trap rm` で確実に削除 |
| PAT との関係 | PAT も使えるが、NTLM が優先（一般メンバーは PAT 発行不要） |

### 1.4 jq（JSON プロセッサ）

| 項目 | 内容 |
|------|------|
| 用途 | コメント本文・REST API JSON body の安全な構築（コマンドインジェクション対策） |
| 利用スキル | `pr-review` |
| インストール | `winget install --id jqlang.jq --accept-package-agreements --accept-source-agreements` |
| 確認 | `jq --version` |
| 補足 | ユーザー入力由来の値（PR コメント本文・ファイルパス・スレッド ID 等）を JSON に埋め込む際、シェル文字列補間を経由するとコマンドインジェクションのリスクがある。必ず `jq -n --arg` / `--argjson` で構築すること |

### 1.5 curl（HTTP クライアント）

| 項目 | 内容 |
|------|------|
| 用途 | TFS Server NTLM 認証経路で REST API を直接呼ぶ（`az devops` 拡張は TFS 非対応のため curl 必須） |
| 利用スキル | `pr-review` |
| インストール | **Windows 10/11 標準で同梱**（`C:\Windows\System32\curl.exe`、インストール不要） |
| 確認 | `curl --version` |
| 補足 | macOS / Linux でも標準で同梱。万が一不在の場合は `winget install --id cURL.cURL --accept-package-agreements` で導入可能 |
| 推奨オプション | `-sS --max-time 30 --ntlm --netrc-file <file> -o <tmpfile> -w '%{http_code}'`。PAT/PASS をコマンドライン引数（`-u user:pass`）に渡すことは禁止。`-fsSL` は HTTP コード分岐ができないため使わない（SSOT: `${CLAUDE_PLUGIN_ROOT}/references/http-error-handling.md` セクション 3） |

---

## 2. LSP プラグイン依存ツール

> **カテゴリ B**（依存プラグイン由来）に該当。短期的には `env-setup` で管理するが、中期的には依存プラグイン（`csharp-lsp` / `typescript-lsp`）側に責務移譲を予定。

### 2.1 csharp-ls（C# Language Server）

| 項目 | 内容 |
|------|------|
| 用途 | C# シンボル解決・参照追跡（csharp-lsp プラグインのバックエンド） |
| 利用スキル | code-review-implementation / code-review-architecture / code-review-security（C# レビュー時） |
| インストール | `dotnet tool install --global csharp-ls` |
| 確認 | `csharp-ls --version` |
| 前提 | .NET SDK 8.0 以上 |
| 補足 | グローバルインストール。`%USERPROFILE%\.dotnet\tools` が PATH に含まれている必要あり |

### 2.2 typescript-language-server

| 項目 | 内容 |
|------|------|
| 用途 | TypeScript / JavaScript シンボル解決（typescript-lsp プラグインのバックエンド） |
| 利用スキル | code-review-frontend / code-review-implementation（TS/JS レビュー時） |
| インストール | `npm install --global typescript-language-server typescript` |
| 確認 | `typescript-language-server --version` |
| 前提 | Node.js LTS |

### 2.x LSP バイナリと LSP プラグインの責務境界

`csharp-lsp` / `typescript-lsp` プラグイン（Anthropic 公式）は **LSP サーバーバイナリ自体のインストールは行わない**。
プラグインは LSP サーバーへの接続定義（`lspServers` 設定）を提供するのみ。

| 担当 | 責任範囲 |
|------|---------|
| `csharp-lsp` / `typescript-lsp` プラグイン | LSP サーバーへの接続定義（コマンド名・拡張子マッピング・stdio 起動設定） |
| `env-setup` スキル（本スキル） | LSP サーバーバイナリ（`csharp-ls` / `typescript-language-server`）のインストール・存在確認 |

利用者は **両方** が揃っていないと LSP 機能が動作しない:
1. プラグインインストール: `deep-code-review` プラグインの `dependencies` に登録済み（自動連動）
2. バイナリインストール: 本スキル（env-setup）が担当 → 「環境構築して」依頼で実行

---

## 3. 動的検証用ランタイム / ツール

> **カテゴリ C**（動的検証用・任意）に該当。**deep-code-review プラグインの責務範囲外**。ユーザーが明示的に要求した場合のみ自動セットアップする。中期的には独立プラグイン `tooling-installer`（仮称）に分離予定。

### 3.1 .NET SDK 8.0+

| 項目 | 内容 |
|------|------|
| 用途 | C# / ASP.NET / .NET Framework のビルド・テスト実行・dotnet list package --vulnerable |
| 利用スキル | code-review-implementation（linter-static-analysis）/ code-review-testing（test-runner）/ code-review-security（dependency-safety） |
| インストール | `winget install --id Microsoft.DotNet.SDK.8 --accept-package-agreements --accept-source-agreements` |
| 確認 | `dotnet --version` |
| 補足 | .NET Framework のビルドは別途 MSBuild / Visual Studio Build Tools が必要な場合あり |

### 3.2 Node.js LTS

| 項目 | 内容 |
|------|------|
| 用途 | npm / eslint / prettier / jest / vitest 等の Node 系ツール基盤 |
| 利用スキル | typescript-language-server / Vue.js / JavaScript レビュー全般 |
| インストール | `winget install --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements` |
| 確認 | `node --version` / `npm --version` |

### 3.3 Python 3.10+

| 項目 | 内容 |
|------|------|
| 用途 | フックスクリプト・補助スクリプト・convert-html スキル等 |
| 利用スキル | プラグイン横断 |
| インストール | `winget install --id Python.Python.3.12 --accept-package-agreements --accept-source-agreements` |
| 確認 | `python --version` |

### 3.4 PowerShell 7+

| 項目 | 内容 |
|------|------|
| 用途 | pwsh ベースの CI スクリプト・カスタムビルドスクリプト実行 |
| 利用スキル | code-review-implementation / code-review-testing（プロジェクト固有） |
| インストール | `winget install --id Microsoft.PowerShell --accept-package-agreements --accept-source-agreements` |
| 確認 | `pwsh --version` |

---

## 4. ツール追加時の手順

新規ツールを管理対象に追加する手順:

1. 本ファイル（`tools-catalog.md`）に **用途・インストール方法・確認コマンド・前提・補足** を追加
2. `${CLAUDE_SKILL_DIR}/SKILL.md` の管理対象一覧表にも追記
3. 必要に応じて呼び出し元スキルの利用案内に「不足時は `env-setup` を呼ぶ」と記載

---

## 5. 認証ツールの取り扱い

`gh auth login` / `az login` などの **認証情報入力** は本スキルで自動化しない。
ユーザーがインタラクティブに実施する必要がある。

トークン・パスワード等の永続化は以下のいずれかにユーザーが選択する:

- credentials-manager プラグインでの登録（標準ストア `.claude/.local/plugins/credentials-manager/credentials.json`。`tfs-password` 等のエントリとして。connector が解決）
- OS の安全な保管領域（Windows: DPAPI / macOS: Keychain / Linux: Secret Service）
- 環境変数（`GH_TOKEN` / `AZURE_DEVOPS_EXT_PAT`）

PAT を使う場合の環境変数:

| ツール | 環境変数 | 用途 |
|--------|---------|------|
| GitHub | `GITHUB_TOKEN` または `GH_TOKEN` | gh CLI が自動利用 |
| Azure DevOps | `AZURE_DEVOPS_EXT_PAT` | az devops 拡張の認証 |

---

## 6. プラットフォーム別の注意

本プラグインは Windows 環境を主想定としている。

- 主要パッケージマネージャ: `winget`
- 補助: `dotnet tool` / `npm -g` / `pip` / `az extension`
- macOS / Linux サポートが必要になった場合は本ファイルにプラットフォーム別欄を追加すること（現状は範囲外）
