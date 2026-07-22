# deep-code-review

> **注記**: 本プラグインは Anthropic 公式 `claude-plugins-official` の同名だった `code-review` とは無関係の個人開発拡張です。**Azure DevOps / オンプレ TFS(NTLM) 対応・8 言語 + 主要 FW の観点プロファイル・spec-inference・Agent Teams** を独自の差別化点として持ちます。

コード変更（ブランチ差分・プルリクエスト・特定ファイル）を **観点別レビュースキル群** で多角的にレビューし、優先度付きの統合サマリと最終判定（`Ready to Merge` / `Needs Attention` / `Needs Work`）を返す協業型コードレビュープラグイン。

> **関連プラグイン**: テストの実行・検証（8 レベルの動的テスト・実施・報告・再テスト）は `deep-test` プラグインが担当します（本プラグインはコード変更・PR のレビューに特化し、テスト実行そのものは行いません）。

> **対応環境**: 現バージョンは **Windows 環境を主想定**（外部依存ツールのインストールに `winget` を使用）。macOS / Linux は将来対応予定。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。
スキルが実行時に参照するのは各スキル配下の `SKILL.md` と `references/` です。

> **ロードマップ・ガバナンス**: バージョン別計画・共通化昇格基準・リリース判定ルールは [`references/roadmap.md`](references/roadmap.md) を参照。

## 導入手順

### 前提

- Claude Code がインストール済み
- 依存プラグイン: `connector`（同一マーケットプレイス内・インストール時に自動解決）+ `claude-plugins-official` 所属の 4 プラグイン（後述「外部依存プラグイン（dependencies）」の手順 1〜2 が必要）

### A. マーケットプレイス経由インストール（推奨）

```text
/plugin marketplace add https://github.com/dmajima/claude-plugins
/plugin install deep-code-review@dmajima-claude-plugins
```

### B. ローカル複製してインストール（オフライン・企業内環境向け）

公開マーケットプレイスにアクセスできない環境では、リポジトリをローカルに複製してから登録します。

```bash
# 1. リポジトリを複製
git clone https://github.com/dmajima/claude-plugins <local-path>

# 2. 必要に応じてブランチ・タグ切替
cd <local-path>
git checkout <tag-or-branch>
```

```text
# 3. ローカルパスでマーケットプレイスを登録
/plugin marketplace add <local-path>

# 4. プラグインをインストール
/plugin install deep-code-review@dmajima-claude-plugins
```

### C. 自動更新の有効化

`~/.claude/settings.json` の `extraKnownMarketplaces` で `autoUpdate: true` を設定すると、セッション起動時にマーケットプレイス + インストール済みプラグインが自動更新されます。

```json
{
  "extraKnownMarketplaces": {
    "dmajima-claude-plugins": {
      "source": { "type": "github", "repo": "dmajima/claude-plugins" },
      "autoUpdate": true
    }
  }
}
```

`autoUpdate: false` の場合は `/plugin update` を手動実行することで最新化できます。

### D. 依存関係のインストール

クロスマーケットプレイス依存（`claude-plugins-official` 所属の 4 プラグイン: github / csharp-lsp / typescript-lsp / microsoft-docs）は以下の 3 ステップで解決します（ADR-028 準拠。各手順の詳細解説は後述「外部依存プラグイン（dependencies）」セクションを参照）。

**D-1. 依存マーケットプレイスの追加**

```text
/plugin marketplace add anthropics/claude-plugins-official
```

**D-2. 自動更新の有効化（`~/.claude/settings.json` の `extraKnownMarketplaces`）**

```json
{
  "extraKnownMarketplaces": {
    "claude-plugins-official": {
      "source": { "type": "github", "repo": "anthropics/claude-plugins-official" },
      "autoUpdate": true
    }
  }
}
```

**D-3. 依存プラグインの個別インストール（自動解決失敗時のみ）**

D-1 実施済みなら、メインプラグインのインストール（上記セクション A の `/plugin install deep-code-review@dmajima-claude-plugins`）時に `plugin.json` の `dependencies` が自動解決され、以下 4 依存プラグインが連動インストールされます。**自動解決に失敗した場合のみ** 各依存を個別にインストールしてください:

```text
/plugin install github@claude-plugins-official
/plugin install csharp-lsp@claude-plugins-official
/plugin install typescript-lsp@claude-plugins-official
/plugin install microsoft-docs@claude-plugins-official
```

## 使い方

### トリガーフレーズ例

```
このブランチをレビューして
PR #123 をレビューして
https://dev.azure.com/org/project/_git/repo/pullrequest/45 をレビュー
セキュリティ観点だけレビューして                     # → code-review-security 単独実行
フロントエンドの変更を見て                           # → code-review-frontend 単独実行
PR #123 の未解決コメントを確認して                   # → pr-review 内の解消判定
仕様書 docs/specs/order.md と整合性を確認して        # → spec 引数経由で仕様整合性チェック
```

### モードの違い（観点別スキル粒度）

| モード | 動員観点別スキル | 内訳エージェント（権限なければ SKIPPED） | 用途 |
|--------|----------------|-----------------------------------------|------|
| 標準 | 5種：impl / testing / security / architecture / frontend（差分内容により architecture / frontend は省略可） | 最大10種：impl + linter + perf + test + runner + sec + dep + arch + dba + web | 通常のコードレビュー（既定） |
| 簡易 | 3種：impl / testing / security の必須トリオ | 最大7種：impl + linter + perf + test + runner + sec + dep | 軽微な修正・時間 / コスト制約 |

> **粒度の注意**: モード判断は **観点別スキル単位**。各観点別スキル内のエージェント（例: `code-review-implementation` 内の linter / perf）は通常通り並列起動される。動的検証は対応する Bash 権限がなければ SKIPPED として記録される（「未実施 ≠ 問題なし」）。

非対話モード（CI/CD・SDK 経由）では **標準モード**。

### PR レビューの流れ

1. `pr-review` スキルが PR 識別子（URL or ID）を受領しホスト判定
2. 必要な外部ツール（gh / az / azure-devops 拡張）の存在確認、不足時は `env-setup` 経由でインストール
3. PR メタ情報・差分・スレッド取得
4. 未解決コメントの **解消判定 → ネイティブステータス更新**（GitHub: resolveReviewThread / Azure DevOps: status=fixed）
5. `code-review` オーケストレーターへ委譲し観点別スキル並列実行
6. レビュー結果を **行範囲指定でインラインコメント追加**
7. 完了報告

### 必要な認証

| ホスト | 推奨認証 | 補助認証 | 備考 |
|-------|--------|---------|------|
| GitHub | `gh auth login`（OAuth） | `GH_TOKEN` 環境変数（PAT） | `--with-token < token.txt` 例示は使わない（平文ファイル禁止） |
| クラウド Azure DevOps（dev.azure.com） | `az login`（MS アカウント） | `AZURE_DEVOPS_EXT_PAT` 環境変数 | `az devops invoke` / `az rest` が動作 |
| **オンプレ TFS Server**（自社 TFS） | **NTLM（既存ドメインアカウント）** | PAT | **`az devops` 拡張は TFS 非対応**。`curl --ntlm --netrc-file` で REST API を直接呼ぶ |

### オンプレ TFS Server の NTLM 認証セットアップ

**オンプレ TFS Server** を使う場合、PAT を発行せずに **既存のドメインアカウント** で動作可能（NTLM 認証）。

> **実装の所在と認証情報ストアの前提（U12）**: 以下の手順（credentials.json 登録・netrc 経由 curl 等）は **connector プラグイン（azure 系スキル）側の内部実装** の解説です。pr-review スキルは PR 操作を connector に委譲するのみで、NTLM 認証処理・認証情報取得を自前では行いません（`credentials.json` を直接参照しません）。**connector に接続していれば credentials-manager を別途直接呼び出す必要はなく、deep-code-review は credentials-manager を直接依存に持ちません**（connector が抽象化層）。利用者が行う作業は「1. TFS パスワードを **credentials-manager プラグイン経由で登録** する」だけです。登録先は credentials-manager の標準ストア `.claude/.local/plugins/credentials-manager/credentials.json`（リポジトリ優先 → ホーム。後方互換で従来パス `~/.claude/credentials.json` も connector が参照）で、connector がこれを解決します。

```powershell
# 1. TFS パスワードを credentials-manager プラグインで "tfs-password" エントリとして登録（初回のみ・手動）
#    → credentials-manager 標準ストア .claude/.local/plugins/credentials-manager/credentials.json に保存される
#    最低限必要なフィールド:
#    {
#      "credentials": {
#        "tfs-password": {
#          "type": "password",
#          "username": "<your-username>",
#          "value": "<password>",
#          "urls": ["https://<tfs-host>/*"],
#          "domains": ["<tfs-host>"],
#          "auth_method": "ntlm:<your-username>"
#        }
#      }
#    }
#    ※未設定で pr-review スキルを起動すると、最初にユーザーへ問い合わせます。

# 2. 利用時は環境変数経由で取得（null 文字列を弾く）※connector 内部の解決例。実体は connector が複数ストアを横断解決
$env:TFS_HOST = '<tfs-host>'    # 例: tfs.example.com
# credentials-manager 標準ストアを解決（リポジトリ優先 → ホーム。後方互換で従来パスも）
$repoRoot = (& git rev-parse --show-toplevel 2>$null)
$credPath = @(
    (Join-Path $repoRoot '.claude/.local/plugins/credentials-manager/credentials.json'),
    (Join-Path $HOME '.claude/.local/plugins/credentials-manager/credentials.json'),
    (Join-Path $HOME '.claude/credentials.json')          # 後方互換（従来パス）
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
$creds = (Get-Content -LiteralPath $credPath -Raw -Encoding utf8 | ConvertFrom-Json).credentials.'tfs-password'
$env:TFS_USER = $creds.username
$tfsPass      = $creds.value     # SecureString に変換できればより安全
if (-not $env:TFS_HOST) { throw 'TFS_HOST が未設定' }
if (-not $env:TFS_USER) { throw 'tfs-password.username が credentials.json に未設定' }
if (-not $tfsPass)      { throw 'tfs-password.value が credentials.json に未設定' }

# 3. .netrc 経由で curl.exe 呼び出し（PASS をコマンドラインに出さない・try/finally で確実削除）
$Netrc = New-TemporaryFile
$Resp  = New-TemporaryFile
# 必要に応じて NTFS ACL で他ユーザのアクセスを禁止する（例）
$acl = Get-Acl $Netrc.FullName
$acl.SetAccessRuleProtection($true, $false)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $env:USERNAME, 'FullControl', 'Allow')
$acl.AddAccessRule($rule)
Set-Acl -Path $Netrc.FullName -AclObject $acl

try {
    "machine $($env:TFS_HOST)`nlogin $($env:TFS_USER)`npassword $tfsPass" |
        Out-File -LiteralPath $Netrc.FullName -Encoding ascii
    $tfsPass = $null   # メモリ上の PASS を即削除（参照を切る）

    # HTTP コード取得 + switch 分岐は ${CLAUDE_PLUGIN_ROOT}/references/http-error-handling.md セクション 3 を適用
    $HttpCode = & curl.exe -sS --max-time 30 --ntlm --netrc-file $Netrc.FullName `
        -o $Resp.FullName -w '%{http_code}' `
        "https://$($env:TFS_HOST)/tfs/<collection>/<project>/_apis/git/repositories/<repo>/pullrequests?api-version=6.0"
    if ([string]$HttpCode -notmatch '^2\d{2}$') {
        Write-Host "HTTP $HttpCode"
        Get-Content -LiteralPath $Resp.FullName -TotalCount 10 -Encoding utf8
        throw "HTTP $HttpCode"
    }
} finally {
    Remove-Item -LiteralPath $Netrc.FullName -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $Resp.FullName  -Force -ErrorAction SilentlyContinue
}
```

`pr-review` スキルが上記手順を内部で自動化する。詳細は `skills/pr-review/references/azure-devops-tfs-ntlm.md` を参照。

**認証情報未設定時の動作**: connector が解決する credentials-manager ストア（`.claude/.local/plugins/credentials-manager/credentials.json`。後方互換で従来パスも）に必要な情報がない場合、`pr-review` スキルは **API アクセスを試みる前にユーザーへ問い合わせ**ます（PAT 発行 / NTLM パスワード入力 / az login 等の指示を提示、または credentials-manager プラグインでの登録を案内）。これにより、誤った資格情報で外部 API を叩く事故を防ぎます。

### PAT が必要な場合（補助・通常は不要）

NTLM 認証が有効なオンプレ TFS では **NTLM 認証で完結する** ため通常 PAT は不要。以下のいずれかの場合のみ PAT を発行する。

| ケース | 対応 |
|------|------|
| CI/CD パイプライン（ブラウザ認証不可） | PAT 発行 |
| NTLM が無効化された TFS インスタンス | PAT 発行 |
| クラウド Azure DevOps の利用（dev.azure.com） | `az login` を最優先・必要時のみ PAT |
| GitHub PR レビュー | `gh auth login`（OAuth）を最優先・必要時のみ PAT |

PAT 発行手順は各サービスの Web UI（右上ユーザーアイコン → Personal Access Tokens / Settings → Developer settings → Tokens）から行う。発行時の最小スコープ:

| サービス | 必要スコープ |
|---------|------------|
| Azure DevOps（クラウド・オンプレ共通） | `Code` Read & Write, `Pull Request Threads` Read & Write |
| GitHub | `repo`（プライベート）/ `pull_request` / `read:org`（組織リポ時） |

PAT 取得後の保存:

```powershell
# 環境変数経由（推奨：履歴・プロセス引数に残らない）
$env:GH_TOKEN = Read-Host -Prompt 'GH_TOKEN' -AsSecureString |
    ConvertFrom-SecureString -AsPlainText            # GitHub
# または
$env:AZURE_DEVOPS_EXT_PAT = Read-Host -Prompt 'AZURE_DEVOPS_EXT_PAT' -AsSecureString |
    ConvertFrom-SecureString -AsPlainText            # Azure DevOps

# 永続化したい場合は credentials-manager プラグインで登録（標準ストア .claude/.local/plugins/credentials-manager/credentials.json に保存）、または OS の安全な保管領域（DPAPI / Keychain / Secret Service）を利用
```

### 認証情報の取り扱い禁止事項

- 禁止: パスワード・PAT をチャット欄に平文で貼らない（履歴・ログに永続化される）
- 禁止: `setx AZURE_DEVOPS_EXT_PAT <PAT>` で Windows レジストリに永続化しない
- 禁止: `gh auth login --with-token < token.txt` で平文ファイル経由ログインしない
- 禁止: `curl -u user:pass <URL>` でコマンドライン引数渡ししない（`ps` から漏洩）
- 推奨: `Read-Host -AsSecureString` でエコーオフ入力 → 環境変数 → `.netrc` ファイル（temp 生成 + `try/finally` で確実削除。Windows/Git Bash では `chmod` の実効性が限定的なため、主防御は一時ファイルの短命化と確実削除）経由が安全

## クイックスタート（初回利用者向け）

1. **プラグインを有効化**（`/plugin marketplace add ...` 等で追加済みなら自動有効化）
2. **必要ツールのインストール**: 「環境構築して」とだけ Claude に依頼すると `env-setup` スキルが起動し、`gh` / `az` / `jq` 等の不足分をインストール提案する
3. **認証**:
   - GitHub: `gh auth login`（ブラウザでサインイン）または `GH_TOKEN` 環境変数
   - クラウド Azure DevOps: `az login`（**MS アカウントで OK・PAT 不要**）。CI/CD 等の特殊ケースのみ PAT
   - **オンプレ TFS Server**: 下記「オンプレ TFS Server の NTLM 認証セットアップ」セクションを参照（**PAT 不要・既存ドメインアカウントで動作**）
4. **最初のレビュー**:
   - ブランチ差分: 「このブランチをレビューして」
   - PR レビュー: 「PR #123 をレビューして」または PR の URL を貼る
   - ファイル指定: 「`src/Order/Order.cs` をレビューして」
5. **モードを固定したい場合**: `/code-review-standard`（最大 10 種エージェント動員・差分内容により一部省略）または `/code-review-quick`（必須トリオのみ）

> **大規模 / クリティカル変更時**: 標準モード実行中に Agent Teams（コスト最大約 6 倍）の採用提案が表示されることがある。承認すれば多角的議論レビュー、却下すればサブエージェント方式で続行。

## 特徴

- **8 言語 + 主要フレームワークの観点プロファイル**: `coding@dmajima-claude-plugins` がサポートする全言語（C# / Python / JavaScript / TypeScript / HTML / CSS / PHP / SQL）の言語別レビュー観点と、主要 FW（ASP.NET Core / Blazor / WebForms / Laravel / Symfony / WordPress / Flask / Django / FastAPI / Express / NestJS / React / Next.js / Vue / Nuxt / ORM 4 種 / FE ツール 7 種 / SQL 方言 3 種）の観点を `references/languages/` + `references/frameworks/` に収録。差分から言語・FW を自動検出して該当観点を適用
- **観点別マルチエージェントレビュー**: 実装品質・テスト・セキュリティ・アーキテクチャ・フロントエンドの 5 観点スキルが最大 10 種の専門エージェントを並列動員
- **信頼度スコアによる誤検知抑制**: 全指摘に信頼度 0〜100 を付与し、信頼度 60 未満の推測ベース指摘は統合サマリから足切り（除外件数は集計に明示）
- **プロジェクト規約優先の 5 段階解決**: ユーザー指示 > 機械設定（.editorconfig 等） > 文書規約（CLAUDE.md 等） > 既存慣習 > 言語デファクトの順で評価基準を解決
- **レビュー状態の永続化**: state.yaml にブランチ単位で結果を保存し、再レビュー時に前回指摘の解消状態を自動引き継ぎ
- **PR レビュー対応**: GitHub / Azure DevOps（クラウド・オンプレ TFS の NTLM 認証）のサマリー+インラインコメント投稿・スレッド解消管理
- **仕様書ベースの整合性チェック**: inputs フォルダ / `spec=` 引数の仕様書を「あるべき姿」としてレビュー
- **コード信頼性原則**: 提出コードは誤りがある前提で評価し、コードパターンからの規約類推はユーザー承認必須

> バージョン履歴は Git コミット履歴で管理しています。今後の機能計画は [`references/roadmap.md`](references/roadmap.md) を参照。

## 提供機能

### スキル構成

| スキル | 役割 | 主要動員エージェント |
|--------|------|---------------------|
| `code-review` | オーケストレーター（モード選択・スコープ確定・**言語/FW 検出**・**Agent Teams 採用判定**・観点別スキル統合・**信頼度足切り**・Verdict 判定） | — |
| `code-review-implementation` | 実装品質観点 | implementation-engineer / linter-static-analysis / performance-reviewer |
| `code-review-testing` | テスト観点 | test-engineer / test-runner |
| `code-review-security` | セキュリティ観点 | security-engineer / dependency-safety |
| `code-review-architecture` | アーキテクチャ観点（DB含む） | architect / dba |
| `code-review-frontend` | フロントエンド観点 | web-designer |
| `code-review-spec-inference` | **期待挙動の推論支援**（PR description / コメント / 外部リンクから「あるべき姿」を推論） | — |
| `pr-review` | PR レビュー（GitHub / Azure DevOps 両対応・I/O アダプタ層） | code-review に委譲 + spec-inference 連携 |
| `env-setup` | 外部依存ツールの環境構築（gh / az / csharp-ls / typescript-language-server 等。将来独立プラグイン化予定） | — |

### Agent Teams パターン

差分の主たる性質に応じて、5つの事前定義パターンから最適なチームを選定する。

| パターン | 採用条件 | チーム構成 | 前段サブエージェント |
|---------|---------|-----------|--------------------|
| `quality-assurance` | 標準的な大規模レビュー（10ファイル超 or 1,000行超） | arch(リード) + impl + test + sec | linter / perf / dep / runner |
| `security-compliance` | 認証/決済/PII/外部API/OSS依存追加 | sec(リード) + impl + legal + infra | dep / linter / dba（必要時） |
| `system-design` | 大規模リファクタ・設計変更・技術選定 | arch(リード) + impl + sec + pl | linter / perf / runner |
| `data-quality-extended` | DB スキーマ・マイグ・SP・大量クエリ | arch(リード) + impl + test + sec | **dba（重点）** + linter / perf / runner |
| `frontend-quality-extended` | 大規模UI・Vue.js設計・Liquid再構築 | arch(リード) + impl + test + sec | **web-designer（重点）** + linter / runner |

**フォールバック**: 簡易モード / 軽微変更 / `TeamCreate` 不可 / 非対話モード / ユーザー却下 → 観点別スキルのサブエージェント並列方式（既定のフォールバック動作）。

詳細な選定フロー・パターン定義は `skills/code-review/references/flow/team-selection.md` を参照。

### 対応言語・フレームワーク

差分から言語・FW を自動検出し（`references/language-detection.md`）、該当する観点プロファイルをレビューエージェントに適用する。

| 区分 | 対応 |
|------|------|
| 言語（8 種） | C#（.NET / .NET Framework）/ Python / JavaScript / TypeScript / HTML / CSS（Sass 含む）/ PHP / SQL |
| .NET 系 FW | ASP.NET Core（MVC / Web API / Minimal API）/ Entity Framework Core / Blazor（Server / WASM）/ ASP.NET WebForms |
| PHP 系 FW | Laravel / Symfony / WordPress |
| Python 系 FW | Flask / Django / FastAPI |
| JS/TS 系 FW | Express 5 / NestJS / React / Next.js / Vue 3 / Nuxt |
| ORM | Prisma / Entity Framework Core / SQLAlchemy / Eloquent |
| FE ツール | Vite / Tailwind CSS / Vitest / Playwright / Jest / Sass / Bootstrap |
| SQL 方言 | MySQL・MariaDB / SQL Server（T-SQL）/ PostgreSQL |
| テンプレートエンジン | Razor（.cshtml）/ Blade / Twig / Jinja2 / Liquid / DotLiquid |

観点プロファイル未収録の言語（Go / Rust / Ruby 等）は「未対応言語」として統合サマリに明示し、プロジェクト規約と汎用観点のみで評価する（推測規約での指摘はしない）。

### カスタムコマンド

| コマンド | 動作 |
|---------|------|
| `/code-review-standard [scope]` | 標準モード（最大 10 種エージェント動員・差分内容により一部省略）でレビュー |
| `/code-review-quick [scope]` | 簡易モード（impl / test / sec のみ）でレビュー |
| `/clear-worktree` | PR レビュー用 worktree の一覧表示・対話削除（引数なし） |

### 共有エージェント（13 種）

`agents/` 配下にプラグイン共有のエージェント定義を配置。観点別スキルから `subagent_type` で起動されるものと、Agent Teams パターンでメンバーとして利用されるものを併載する。

| 用途 | エージェント |
|------|-------------|
| 観点別スキル動員（10 種） | implementation-engineer / test-engineer / security-engineer / linter-static-analysis / test-runner / performance-reviewer / dependency-safety / architect / dba / web-designer |
| Agent Teams 専用（3 種） | legal-advisor（`security-compliance`）/ infrastructure-engineer（`security-compliance`）/ project-leader（`system-design`） |

> 観点別スキル動員エージェントのうち architect / implementation-engineer / security-engineer / test-engineer / dba は Agent Teams のメンバーとしても利用される。

## 外部依存プラグイン（dependencies）

`plugin.json` の `dependencies` に以下を登録（プラグインインストール時に自動連動）。種別は依存ポリシー（`dependencies-policy.md`）の分類に従う。`connector` は **必須依存**（PR レビューの I/O を担い、不在では PR レビューが成立しない）。`claude-plugins-official` 所属の 4 件は **推奨依存**（あるとレビュー精度・網羅性が向上する機能拡張。**いずれも不在時は縮退動作し、レビュー自体は継続する**）。

| プラグイン | 種別 | 用途 | 利用箇所 / 不在時の縮退動作 | アクセス先 | コード送信 |
|-----------|------|------|--------------------------|----------|-----------|
| `connector`（同一マーケ） | **必須** | PR メタ取得・コメント投稿の I/O + **外部接続の認証情報解決** | `pr-review` が全 PR 操作を委譲。**認証情報も connector が credentials-manager ストア等から解決**（下記「認証情報取得モデル」参照）。**不在では PR レビュー不可** | GitHub / Azure DevOps API | あり（各ホスト内に留まる） |
| `github@claude-plugins-official` | 推奨 | GitHub 公式 MCP（補助的なメタ参照） | 主経路は `connector`（gh CLI 経由）。MCP は補助で、**不在時は connector のみで動作** | `api.githubcopilot.com/mcp/` | あり（GitHub 内に留まる） |
| `csharp-lsp@claude-plugins-official` | 推奨 | C# シンボル解決 | C# ファイル読解時に Claude Code のコード知能（シンボル解決・型情報）を **透過的に補強**し、C# を扱う観点別スキル（`code-review-implementation` / `-architecture` / `-security`）の読解精度が向上する（レビューエージェントが明示的に呼ぶツールではなく、環境に導入されていれば自動で効く。詳細な利用スキルは `skills/env-setup/references/tools-catalog.md` 2.1）。**不在時は静的読解のみで継続**（透過的縮退でスキル側に明示分岐は持たない。`env-setup` がツール不在を検出した場合は警告のみで処理継続） | **ローカルのみ**（`csharp-ls`） | なし |
| `typescript-lsp@claude-plugins-official` | 推奨 | TS/JS シンボル解決 | TS/JS ファイル読解時にコード知能を透過的に補強し、TS/JS を扱う観点別スキル（`code-review-frontend` / `code-review-implementation`）の読解精度が向上する（`tools-catalog.md` 2.2）。**不在時は静的読解のみで継続** | **ローカルのみ**（`typescript-language-server`） | なし |
| `microsoft-docs@claude-plugins-official` | 推奨 | .NET / ASP.NET 一次情報照合 | `code-review-architecture` が .NET API の非推奨・推奨パターンを learn.microsoft.com で照合（`references/frameworks/dotnet.md` の動的照合）。**不在時は照合をスキップ** | `learn.microsoft.com`（**検索クエリのみ送信、コード非送信**） | なし |

> **種別の意味**: 推奨依存は `dependencies` に登録するが（`dependencies-policy.md` 節1「推奨依存 → `plugin.json` の `dependencies`（任意）」）、動作の前提ではない。C#/TS を扱わない・GitHub を使わないレビューでは、対応する推奨依存が未解決でもレビューは通常どおり成立する。
>
> **採用しないプラグイン**: 外部AI/SaaS にコードを送信するもの（coderabbit / sonarqube / autofix-bot 等）はプロダクト情報保護のため不採用。

### 認証情報取得モデル（connector 委譲・U12）

外部接続（GitHub / Azure DevOps クラウド / オンプレ TFS の PR API、外部 URL fetch）の **認証情報取得は `connector` に委譲**します。connector が **credentials-manager プラグインの認証情報ストア**（`.claude/.local/plugins/credentials-manager/credentials.json`。リポジトリ優先 → ホーム。後方互換で従来パス `~/.claude/credentials.json` も参照）を含む複数ソース（`gh` / `az` CLI・環境変数等）から解決します。

- **connector に接続していれば credentials-manager は不要**: deep-code-review は credentials-manager を **直接依存に持たず**（`plugin.json` の `dependencies` に含めない）、credentials-manager スキルを直接呼び出しもしません。connector が抽象化層として credentials-manager ストアを解決するためです。
- **認証情報の登録・保存**はユーザーが **credentials-manager プラグイン経由**で行います（それが「credentials-manager 連携前提」の実体）。deep-code-review 自身は認証情報を保存せず、`credentials.json` を直接参照しません。
- 認証情報の **値そのもの**はユーザー出力・PR コメント・ログに出さず、レビュー対象コード内の機密パターンは伏字化します。

### クロスマーケットプレイス依存の設定（ADR-028）

上記依存プラグインは `claude-plugins-official` マーケットプレイスに所属しています。利用するには以下の設定が必要です。

**手順 1: 依存マーケットプレイスの追加（必須）**

```text
/plugin marketplace add anthropics/claude-plugins-official
```

依存先マーケットプレイスが未追加の場合、Claude Code 公式仕様により `dependencies` は未解決のまま放置されます（自動マーケットプレイス追加機構はありません）。

**手順 2（方法 A）: `~/.claude/settings.json` に `extraKnownMarketplaces` を追加**

```json
{
  "extraKnownMarketplaces": {
    "claude-plugins-official": {
      "source": { "type": "github", "repo": "anthropics/claude-plugins-official" },
      "autoUpdate": true
    }
  }
}
```

**手順 2（方法 B）: CLI でインストール**

> **前提**: 手順 1 の依存マーケットプレイス追加（および任意で方法 A の `extraKnownMarketplaces` 設定）が完了していること。クロスマーケットプレイス依存（`claude-plugins-official` 所属プラグイン）は、依存先マーケットプレイスが既知でない限り自動解決されません。

```bash
/plugin install deep-code-review@dmajima-claude-plugins
```

手順 1 実施済みの環境では、インストール時に `plugin.json` の `dependencies` が自動解決され、`claude-plugins-official` の依存プラグイン（github / csharp-lsp / typescript-lsp / microsoft-docs）が連動インストールされます。自動解決に失敗した場合は各依存を個別にインストールしてください:

```bash
/plugin install github@claude-plugins-official
/plugin install csharp-lsp@claude-plugins-official
/plugin install typescript-lsp@claude-plugins-official
/plugin install microsoft-docs@claude-plugins-official
```

> **補足**: 同マーケットプレイスの `connector` プラグイン（PR コメント投稿等の I/O を担当）は同一マーケットプレイス内依存のため、本プラグインのインストール時に自動解決されます。

## 動的検証コマンドの追加方法

`linter-static-analysis` / `test-runner` / `dependency-safety` は対応する Bash 権限が許可されている場合のみ実コマンドを実行する。

| エージェント | 役割 | 追加すべき Bash 権限例 |
|------------|------|-----------------------|
| `linter-static-analysis` | ビルド・Linter | `Bash(dotnet *)` / `Bash(npm *)` / `Bash(eslint *)` / `Bash(prettier *)` / `Bash(tsc *)` / `Bash(pwsh *)` 等 |
| `test-runner` | ユニットテスト実行 | `Bash(dotnet *)` / `Bash(npm *)` / `Bash(jest *)` / `Bash(vitest *)` / `Bash(pytest *)` / `Bash(pwsh *)` 等 |
| `dependency-safety` | 脆弱性スキャン | `Bash(dotnet *)` / `Bash(npm *)` / `Bash(pip-audit *)` / `Bash(osv-scanner *)` / `Bash(trivy *)` 等 |

権限が **追加されていない場合** は SKIPPED として明示し、未確認事項に記載される（「未実施」を「問題なし」と書かない設計）。

利用側プロジェクトの `.claude/settings.json` または対応する観点別スキルの `SKILL.md` の `allowed-tools` に追加。

## ファイル構成

```
plugins/deep-code-review/
├── .claude-plugin/
│   └── plugin.json                            # dependencies に connector（同一マーケ）+ github/csharp-lsp/typescript-lsp/microsoft-docs（クロスマーケ）を登録
├── LICENSE                                    # MIT License
├── README.md                                  # 本ファイル（人間向け・現行バージョンのみ記載）
├── agents/                                    # 共有エージェント定義（観点別スキル動員 10 種 + Agent Teams 用 3 種）
│   ├── architect.md                           # 観点別スキル / Agent Teams 共通
│   ├── dba.md                                 # 観点別スキル / Agent Teams 共通
│   ├── dependency-safety.md                   # 観点別スキル
│   ├── implementation-engineer.md             # 観点別スキル / Agent Teams 共通
│   ├── infrastructure-engineer.md             # Agent Teams（security-compliance）
│   ├── legal-advisor.md                       # Agent Teams（security-compliance）
│   ├── linter-static-analysis.md              # 観点別スキル
│   ├── performance-reviewer.md                # 観点別スキル
│   ├── project-leader.md                      # Agent Teams（system-design）
│   ├── security-engineer.md                   # 観点別スキル / Agent Teams 共通
│   ├── test-engineer.md                       # 観点別スキル / Agent Teams 共通
│   ├── test-runner.md                         # 観点別スキル
│   └── web-designer.md                        # 観点別スキル
├── commands/                                  # カスタムコマンド
│   ├── code-review-standard.md
│   ├── code-review-quick.md
│   └── clear-worktree.md                      # worktree 対話削除
├── references/                                # プラグイン共通 SSOT モジュール + 選定／集約規範
│   ├── CLAUDE.md                              # 読み込みガイド（AI 向け原則・ナビゲーション）
│   ├── README.md                              # 共通 references の人間向けインデックス
│   ├── universal-rules.md                     # Universal Rules U1-U16 索引（全スキル共通 SSOT・300行分割）
│   ├── universal-rules-environment.md         # └ U1-U6 環境/セッション系（詳細）
│   ├── universal-rules-process.md             # └ U7-U11 プロセス系（詳細）
│   ├── universal-rules-quality.md             # └ U12-U16 品質系（詳細）
│   ├── skill-rules-matrix.md                  # スキル横断ルール ID 体系
│   ├── agents.md                              # エージェント選定・プロンプト構成
│   ├── language-detection.md                  # 言語・FW 検出手順と観点プロファイル対応表
│   ├── conventions-resolution.md              # レビュー基準（規約）の 5 段階優先順位解決
│   ├── languages/                             # 言語別レビュー観点プロファイル（8 言語）
│   │   ├── CLAUDE.md                          # 読み込みガイド
│   │   ├── csharp.md / python.md / javascript.md / typescript.md
│   │   └── html.md / css.md / php.md / sql.md # sql.md は MySQL / SQL Server / PostgreSQL 方言対応
│   ├── frameworks/                            # FW 別レビュー観点プロファイル
│   │   ├── CLAUDE.md                          # 読み込みガイド
│   │   ├── dotnet.md                          # ASP.NET Core / EF Core / Blazor / WebForms
│   │   ├── php-web.md                         # Laravel / Symfony / WordPress
│   │   ├── python-web.md                      # Flask / Django / FastAPI
│   │   ├── node.md / react.md / vue.md        # Express・NestJS / React・Next.js / Vue 3・Nuxt
│   │   ├── frontend-tooling.md                # Vite / Tailwind / Vitest / Playwright / Jest / Sass / Bootstrap
│   │   └── orm.md                             # Prisma / EF Core / SQLAlchemy / Eloquent
│   ├── comment-resolution-judge.md            # 未解決コメントの解消判定規範
│   ├── comment-sanitization.md                # コメント本文サニタイズ索引（300行分割）
│   ├── comment-sanitization-patterns.md       # └ セクション1-4 サニタイズ対策・sed パターン（詳細）
│   ├── comment-sanitization-escaping.md       # └ セクション5-5.6 予約文字エスケープ・投稿前チェック（詳細）
│   ├── common-references.md                   # 観点別 5 スキルの共通参照インデックス
│   ├── command-common-behavior.md             # コマンド（quick/standard）の共通動作定義
│   ├── http-error-handling.md                 # HTTP ステータス分岐・REST API エラー処理
│   ├── roadmap.md                             # 機能計画・共通化昇格基準・リリース判定
│   ├── safe-external-fetch.md                 # SSRF 対策・外部 URL ホワイトリスト
│   ├── scope-out-policy.md                    # 別 PR 推奨禁止・PR 外への影響禁止
│   ├── severity-ranking.md                    # 重要度付与・重複統合・信頼度足切り
│   └── scripts/                               # 自動化スクリプト
│       ├── fetch/
│       │   └── safe_fetch.sh                  # SSRF ガード付き外部 fetch（ホワイトリスト・内部 IP 拒否・IP ピン留め）
│       └── worktree/                          # PR レビュー時の worktree 管理
│           ├── setup.sh                       # worktree 作成・更新
│           ├── teardown.sh                    # worktree 削除
│           └── list.sh                        # worktree 一覧出力
└── skills/
    ├── code-review/                           # オーケストレーター
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── evals/                             # 動作分岐検証ケース（case-01〜29 + README）
    │   └── references/                        # オーケストレーター固有リファレンス（フォルダ分類済み）
    │       ├── CLAUDE.md                      # 読み込みガイド
    │       ├── flow/                          # 実行フロー（flow.md 索引 + flow-steps-early.md / flow-steps-review.md / flow-steps-output.md / mode-selection.md / scope-detection.md / team-selection.md 索引 + team-selection-patterns.md / team-selection-flow.md）
    │       ├── state/                         # 状態管理（state-management.md / inputs-management.md / code-trustworthiness.md）
    │       ├── output/                        # 出力フォーマット（output-format.md 索引 + output-format-details.md / output-verdict.md）
    │       ├── template/                      # テンプレート（output/review-summary.md 索引 + review-summary-body-1.md / review-summary-body-2.md / state/state_template.yaml）
    │       └── quality/                       # 達成チェック（checklist.md）
    ├── code-review-implementation/            # 実装品質観点
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── evals/                             # 動作分岐検証ケース（case-01〜10 + README）
    │   └── references/checklist.md
    ├── code-review-testing/                   # テスト観点
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── evals/                             # 動作分岐検証ケース（case-01〜08 + README）
    │   └── references/checklist.md
    ├── code-review-security/                  # セキュリティ観点
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── evals/                             # 動作分岐検証ケース（case-01〜10 + README）
    │   └── references/checklist.md
    ├── code-review-architecture/              # アーキテクチャ観点
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── evals/                             # 動作分岐検証ケース（case-01〜09 + README）
    │   └── references/checklist.md
    ├── code-review-frontend/                  # フロントエンド観点
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── evals/                             # 動作分岐検証ケース（case-01〜09 + README）
    │   └── references/checklist.md
    ├── code-review-spec-inference/            # 期待挙動推論
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── evals/                             # 動作分岐検証ケース（case-01〜07 + README）
    │   └── references/
    │       ├── checklist.md                   # ルール ID 達成チェック
    │       └── expected-behavior.md           # 期待挙動推論ルール
    ├── pr-review/                             # PR レビュー I/O アダプタ（GitHub / Azure DevOps クラウド・オンプレ TFS）
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── evals/                             # 動作分岐検証ケース（case-01〜37 + README）
    │   └── references/
    │       ├── author-identity.md             # 自著判定の集約ルール
    │       ├── azure-devops.md                # Azure DevOps 共通エントリ
    │       ├── azure-devops-cloud.md          # クラウド Azure DevOps 用 REST API
    │       ├── azure-devops-common.md         # クラウド・オンプレ共通仕様
    │       ├── azure-devops-tfs-ntlm.md       # オンプレ TFS Server NTLM 認証
    │       ├── checklist.md                   # ルール ID 達成チェック（U/P 軸）
    │       ├── comment-posting.md             # インラインコメント投稿 索引（300行分割）
    │       ├── comment-posting-inline.md      # └ セクション7.0-7.4 インライン投稿（詳細）
    │       ├── comment-posting-summary.md     # └ セクション7.5-7.7 サマリースレッド投稿（詳細）
    │       ├── comment-status.md              # コメントステータス管理（インデックス）
    │       ├── comment-status-policy.md       # コメントステータス更新ポリシー
    │       ├── completion-checklist.md        # 完了前チェックリスト索引（A〜F グループ・300行分割）
    │       ├── completion-checklist-execution.md  # └ グループA-C 実施/投稿/順守（詳細）
    │       ├── completion-checklist-reporting.md   # └ グループD-F 報告/自動チェック/未通過対応（詳細）
    │       ├── credentials-precheck.md        # 認証情報の事前確認（Step 1.5）
    │       ├── flow-control.md                # 実行フロー制御（SKILL.md 200 行制約のため分離）
    │       ├── github.md                      # GitHub 用 REST API
    │       ├── local-checkout-review.md       # worktree 利用手順
    │       ├── pr-identifier-validation.md    # PR 識別子バリデーション
    │       ├── pre-post-validation.md         # 投稿前バリデーション 5 項目
    │       ├── re-review-flow.md              # 再レビューフロー（4 パターン分岐）
    │       ├── scope-out-acknowledgment.md    # Pattern D/E 索引（スコープ外了承・修正完了確認・300行分割）
    │       ├── scope-out-pattern-d.md         # └ Pattern D スコープ外了承（詳細）
    │       ├── scope-out-pattern-e.md         # └ Pattern E 修正完了確認・マッピング永続化（詳細）
    │       └── template/comment-templates.md  # コメントテンプレート（署名・インライン冒頭）
    └── env-setup/                             # 外部依存ツール環境構築（将来独立プラグイン化予定）
        ├── SKILL.md
        ├── README.md
        ├── evals/                             # 動作分岐検証ケース（case-01〜10 + README）
        └── references/
            ├── checklist.md
            └── tools-catalog.md
```

## カスタマイズ

### エージェントの追加

1. `agents/<new-agent>.md` に定義を追加
2. 該当する観点別スキルの `SKILL.md` の `allowed-tools` に `Agent(<new-agent>)` を追加
3. `references/agents.md` の選定ルールを更新
4. `references/severity-ranking.md` に評価語マッピングを追加

### 観点別スキルの追加

1. `skills/code-review-<新観点>/SKILL.md` を作成
2. `skills/code-review/SKILL.md` の委譲表に追加
3. `references/agents.md` を更新

### 外部依存プラグインの追加・削除

`plugin.json` の `dependencies` を編集。アクセス先・コード送信有無を README に明記する（プロダクト情報保護のため）。

### 新しい PR ホスト（GitLab / Bitbucket 等）への対応

1. `pr-review/SKILL.md` の対応ホスト表に追加
2. `pr-review/references/<host>.md` を新規作成
3. `env-setup` スキルに必要 CLI を追加

## ライセンス

[MIT License](LICENSE)

## スコープ外

- E2E / 結合 / ブラウザ / 性能テストの実行
- バグ修正の実装（指摘・推奨対応の提示にとどめる）
- リリース可否の最終決定（Verdict は技術観点。最終判断は人間）
- 認証情報の取得・保存（取得は `connector` に委譲。登録・保存は credentials-manager プラグイン経由または `gh auth login` / `az login` / PAT 設定でユーザー側が実施。deep-code-review 自身は認証情報を保存しない）
- 外部 AI / SaaS へのコード送信（プロダクト情報保護のため意図的に避ける設計）
