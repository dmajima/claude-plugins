# credentials-manager

Claude Code セッションをまたいで認証情報（API キー・トークン・パスワード等）を管理するプラグイン。**参照（`credentials-reader`）／管理（`credentials-manager`）／対話 UI（`/credentials-manager:manage`）** を責務分離し、URL/ドメイン関連付けによる自動適用に対応する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。各スキルの動作本体は `skills/credentials-reader/SKILL.md` `skills/credentials-manager/SKILL.md` および `references/` 配下を参照してください。

## 提供機能

| 機能 | 種別 | 責務 |
|-----|------|------|
| `credentials-reader` | スキル | 取得（retrieve）／一覧（list、参照目的）／URL 自動マッチ／プロアクティブ検出。フック経由で最優先起動される軽量スキル |
| `credentials-manager` | スキル | 追加（save）／編集（update）／削除（delete）／修復（repair）。書き込み系の管理操作を担当 |
| `/credentials-manager:manage` | コマンド | `AskUserQuestion` ベースの対話メニュー UI で reader と manager を呼び分ける設定 UI |
| `install_rule_template.sh` | フック (SessionStart) | スコープ判定（user / project）に応じて最重要ルール `credentials-management.md` を `.claude/rules/security/` 配下へ自動配置（既存ファイルは温存） |
| `preempt_credentials_check.sh` | フック (PreToolUse) | 外部通信（`Bash` / `PowerShell` のコマンドを含む）・認証情報系ファイル・コンテンツ内シークレット検出時に Claude へ「`credentials-reader` を最優先起動」と注意喚起 |
| `detect_credentials_in_prompt.sh` | フック (UserPromptSubmit) | ユーザー入力にシークレットパターン検出時、Claude へ「マスキング + `credentials-reader` 起動 + 必要時 `credentials-manager` 引き継ぎ」と通知 |

## 導入手順

### 前提

- Claude Code がインストール済み
- 外部プラグインには依存しない
- 同梱フックの実行には `bash` 4 以上と `jq` が必要（macOS 標準の bash 3.2 では動かない）。前提を欠くと検出フックは何もせずに終了し、`bash` を起動できない環境ではフックそのものが動かない。いずれの場合もスキル・コマンドは影響を受けない
- 前提を欠くときは、セッションの開始時に SessionStart のフックが「検出フックが動作していない」ことを知らせる（下記「SessionStart」参照）

### A. マーケットプレイス経由インストール（推奨）

```text
/plugin marketplace add https://github.com/dmajima/claude-plugins
/plugin install credentials-manager@dmajima-claude-plugins
```

### B. ローカル複製してインストール（オフライン・企業内環境向け）

公開マーケットプレイスにアクセスできない環境では、リポジトリをローカルに複製してから登録します。

```bash
# 1. リポジトリを複製
git clone https://github.com/dmajima/claude-plugins ~/claude-plugins

# 2. ブランチに切替（リリースタグを付けている場合は、タグを指定してもよい）
cd ~/claude-plugins
git checkout main   # 最新追従
```

```text
# 3. ローカルパスでマーケットプレイスを登録
/plugin marketplace add ~/claude-plugins

# 4. プラグインをインストール
/plugin install credentials-manager@dmajima-claude-plugins
```

### C. 自動更新の有効化

`~/.claude/settings.json` の `extraKnownMarketplaces` で `autoUpdate: true` を設定すると、セッション起動時にマーケットプレイス + インストール済みプラグインが自動更新されます。

```json
{
  "extraKnownMarketplaces": {
    "dmajima-claude-plugins": {
      "source": {
        "type": "github",
        "repo": "dmajima/claude-plugins"
      },
      "autoUpdate": true
    }
  }
}
```

`autoUpdate: false` の場合は `/plugin update` を手動実行することで最新化できます。

### D. 依存関係のインストール

依存関係なし。

外部 CLI（git / Python / gh CLI 等）も不要です。Claude Code のみで動作します。

### 動作確認

```text
保存してある認証情報を一覧表示して
```

`credentials-reader` スキルが起動して `credentials.json`（不在時は空ストア表示）の内容を返せば導入成功です。

または対話 UI:

```text
/credentials-manager:manage
```

## 使い方

### 最小例（保存）

ユーザ:
> OpenAI の API キーを保存して

Claude（要約）:
> `credentials-manager` スキルを起動 → 識別名・URL/ドメインを対話で確認 → `openai-api-key` として保存（マスク値表示・保存先パス通知）

### 最小例（参照・自動適用）

ユーザ:
> https://api.openai.com/v1/models から取得して

Claude（要約）:
> `credentials-reader` スキルを起動 → 保存済み認証情報 `openai-api-key` (`sk-p****f456`) を `api.openai.com` に自動適用しました。

確認なしで自動適用されるのは、`https://` の URL で、ホストが確定する一致（`domains[]` の完全一致、ホスト部に `*` を含まない `urls[]` の一致）が 1 件のときだけです。
ホスト部に `*` を含む `urls[]`（`https://*.example.com/...`）や説明文の部分一致、`http://` やスキームの無い URL、ツールによってホストの解釈が分かれる URL（`https://evil.test\@api.example.com/` のように `\` を含むもの、authority に `@` `%` を含むもの）では、候補を示して適用してよいか確認します（非対話モードでは適用しません）。
ホスト部の `*` は 1 つのラベルにだけ一致します（`https://*.example.com/api` は `https://a.example.com/api` に一致し、`https://a.b.example.com/api` や `https://evil.test/x.example.com/api` には一致しません）。

### 応用例

| 目的 | フレーズ | 起動スキル |
|-----|---------|----------|
| URL アクセス時に自動適用 | 「`https://api.openai.com/v1/models` から取得して」 | `credentials-reader` |
| 一覧表示 | 「保存してある認証情報を一覧表示」 | `credentials-reader` |
| プロアクティブ検出 | 「キーは `ghp_xxxxxxxx`」 | `credentials-reader` → 保存承諾時 `credentials-manager` |
| 新規保存 | 「OpenAI の API キー `sk-...` を保存して」 | `credentials-manager` |
| 編集 | 「openai-api-key の値を更新して」 | `credentials-manager` |
| 削除 | 「`openai-api-key` を削除して」 | `credentials-manager` |
| 対話 UI | `/credentials-manager:manage` | コマンド経由で reader/manager を呼び分け |

### URL アクセス時の自動起動について

本プラグインは **明示要求がなくても、ユーザが URL / API エンドポイント / WebFetch / curl / 外部サービス通信を依頼した時点で自動起動** します。グローバルルール `~/.claude/rules/security/credentials-management.md` の有無に関わらず、各 SKILL.md の description が AI トリガー判定で参照されるため、利用者環境にグローバルルールが無くても問い合わせ先として機能します。

参照系（自動マッチ・取得・一覧）は **`credentials-reader`** が起動するため、フック経由の起動コンテキストが軽量化されます。書き込み（保存・編集・削除）が必要になった場合のみ `credentials-manager` に引き継がれます。

さらに本プラグインは下記 3 つのフックで強制力を多重化しています。

## 自動化機構（hooks）

### SessionStart — 最重要ルールテンプレートの自動配置

セッション開始時に `${CLAUDE_PLUGIN_ROOT}/references/templates/rules/security/credentials-management.md` を、プラグインのインストールスコープに応じた以下のディレクトリへコピーします。

| スコープ判定 | 配置先 |
|------------|-------|
| `${CLAUDE_PLUGIN_ROOT}` が `${HOME}/.claude/` 配下にある（user スコープ） | `${HOME}/.claude/rules/security/credentials-management.md` |
| 上記以外（project / local スコープ） | `${CLAUDE_PROJECT_DIR}/.claude/rules/security/credentials-management.md` |

- 既に同名ファイルが存在する場合は **何もしません**（ユーザーの編集を尊重）
- 配置時のみ `additionalContext` で Claude に通知します（配置できなかった場合も、その旨を通知します）
- 配置後は `CLAUDE.md` から `rules/security/credentials-management.md` を参照する 1 行を追記してください（既存運用と整合）

あわせて、検出フック（PreToolUse / UserPromptSubmit）が動く前提（`bash` 4 以上・`jq`・`references/scripts/hooks/lib/` の共通定義）を自己診断します。
検出フックは前提を欠くと何もせずに終了する（フェイルオープン）ため、欠けているものがあれば、検出フックが動作していないことと対処（`jq` のインストール・`bash` の更新・プラグインの入れ直し）をセッションの開始時に Claude へ知らせます。
前提を欠く環境でも、ルールの配置は行います（検出フックの念押しが無い分、ルールで補うため）。このフックは `bash` 3.2 でも動く書き方に限っており、`jq` が無い場合は通知を平文で出力します。
検出フック自身も、前提を欠くときは stderr に 1 行出してから終了します（詳細モードでのみ表示）。

### PreToolUse — 認証情報を扱い得る全ツール呼び出しの注意喚起

以下のいずれかに該当するツール呼び出しを検出した時点で、`hookSpecificOutput.additionalContext` を介して Claude に「`credentials-reader` を最優先起動して照合し、書き込みが必要な場合のみ `credentials-manager` に引き継ぐ」と通知します。

#### 1. ツール種別による検出

| ツール / 条件 | 検出 |
|-----------|------|
| `WebFetch` / `WebSearch` | 常に対象 |
| `mcp__*`（任意の MCP サーバ呼び出し） | 常に対象 |
| `Bash` / `PowerShell` の `command` に対象のコマンド・設定・パターンを含む | 下記 2 / 3 / 5 のいずれか |
| `Bash` / `PowerShell` の `command` が認証情報系ファイルを指す（`cat .env` / `Get-Content ~/.aws/credentials` 等） | 下記 4 のリストに該当 |
| `Read` / `Write` / `Edit` / `MultiEdit` / `NotebookEdit` の `file_path`（`NotebookEdit` は `notebook_path`）が認証情報系 | 下記 4 のリストに該当 |
| `Grep` の `path` / `glob`、`Glob` の `path` / `pattern` が認証情報系ファイルを指す（Grep の `pattern` は検索する正規表現のため対象外） | 下記 4 のリストに該当 |
| `Write` / `Edit` / `MultiEdit` / `NotebookEdit` のコンテンツにシークレットパターン | 下記 5 のいずれか |

#### 2. シェルコマンドの外部通信 / 認証付きクライアント / IaC / シークレット管理 CLI

```text
curl / wget / http / httpie / aria2c
ssh / scp / sftp / rsync / gh
aws / az / gcloud / kubectl / doctl / heroku / firebase / vercel / netlify
docker / podman / psql / mysql / mongosh / mongo / redis-cli
terraform / tofu / ansible / ansible-playbook / helm / pulumi / packer
vault / op / bw
Invoke-WebRequest / Invoke-RestMethod / iwr / irm
Start-BitsTransfer / Net.WebClient / Net.Http.HttpClient / [Net.WebRequest]
```

CLI 名は `curl.exe` / `az.cmd` のような拡張子付きでも検出します。`PowerShell` ではさらに、パス付き（`C:\...\gh.exe` / `.\gh.exe`）・引用符付き（`& 'gh'` / `Start-Process -FilePath "curl.exe"`）の起動と、代入（`$u=gh api user`）やスクリプトブロック（`{gh api user}`）の中の起動も検出します。
別名の `irm` / `iwr` は、行頭・区切りの後・代入の右辺・スクリプトブロックや引用符の中など、コマンドを置ける位置にあるものを検出します。
`gh-pages` や `.\docs\op\` のように、CLI 名の直後に `-` や `\` が続くものは対象外です。

#### 3. 認証情報らしい環境変数の設定

```text
export FOO_TOKEN=...      / set FOO_KEY=...
export FOO_SECRET=...     / export FOO_PASSWORD=...
export FOO_API_KEY=...    / export FOO_AUTH=...
export FOO_CREDENTIAL=... / export FOO_BEARER=...
$env:FOO_TOKEN = ...      / ${env:FOO_KEY} = ...
[Environment]::SetEnvironmentVariable('FOO_SECRET', ...)
Set-Item -Path Env:FOO_PASSWORD ... / New-Item -Path Env: -Name FOO_API_KEY ...
si Env:FOO_TOKEN ...      / ni Env:FOO_KEY ...（Set-Item / New-Item の別名）
setx FOO_TOKEN ...        / setx /M FOO_SECRET ...
```

変数名に認証情報キーワード（`TOKEN` / `KEY` / `SECRET` / `PASSWORD` / `PASSWD` / `API` / `AUTH` / `CREDENTIAL` / `SESSION` / `BEARER` / `PRIVATE`）を含む場合のみ検出し、値の参照（`$env:FOO_TOKEN` を読むだけ）は対象外です。
設定は 1 行で完結するため、照合は改行をまたぎません。PowerShell の書き方は、`Bash` から `pwsh -c` / `powershell -c` で実行した場合も検出します。

大文字小文字の扱いは、照合対象とツールによって次のように異なります（PowerShell はコマンド名の大文字小文字を区別しないため）。

| 照合対象 | `Bash` | `PowerShell` |
|---------|--------|--------------|
| 2 の CLI 名（`curl` 〜 `bw`） | 区別する | 区別しない |
| 2 の PowerShell 系の通信コマンド（`Invoke-WebRequest` 〜 `[Net.WebRequest]`） | 区別しない | 区別しない |
| 3 の `export` / `set` | 区別する | 区別する |
| 3 の PowerShell / Windows の書き方（`$env:` 〜 `setx`） | 区別しない | 区別しない |
| 5 のシークレットパターン | 区別する | 区別する |

#### 4. 認証情報系ファイルパス（ファイル系ツールのパス、シェルのコマンド中のパス）

| 種別 | 対象 |
|-----|------|
| 環境変数定義 | `.env` / `.env.<name>` / `.envrc`（`.env.example` `.sample` `.template` `.dist` `.test` `.spec` は除外） |
| 認証情報ストア | `credentials.json` / `credentials.yml` / `secrets.json` / `secret.json` 等 |
| ツール設定 | `.npmrc` / `.netrc` / `.pgpass` / `.git-credentials` / `.dockercfg` / `~/.config/gh/hosts.yml`（GitHub CLI。Windows では `%AppData%\GitHub CLI\hosts.yml`） |
| 秘密鍵 | `id_rsa` / `id_dsa` / `id_ecdsa` / `id_ed25519` / `id_xmss` |
| クラウド認証 | `~/.aws/credentials` / `~/.aws/config` / `~/.docker/config.json` / `~/.kube/config` / `kubeconfig` / `serviceAccountKey.json` / `application_default_credentials.json`（`~/.aws` / `~/.docker` / `~/.kube` のディレクトリそのものと、配下をワイルドカードだけで指すもの（`~/.aws/*` / `**/.kube/**` 等）を含む） |
| ディレクトリ全体 | `~/.ssh` / `~/.gnupg` とその配下 |
| 拡張子 | `*.pem` / `*.key` / `*.p12` / `*.pfx` / `*.jks` / `*.keystore` / `*.crt` / `*.cer` / `*.der` / `*.asc` / `*.gpg`（拡張子の前に 1 文字以上あるもの） |

シェルのコマンドは、空白・区切り・括弧・引用符・`=` で区切ったトークンごとにこの表で判定します（`.env` / `.aws` などの手掛かりの語を含むコマンドだけ）。
`.env*` / `*.pem` のようなワイルドカードも対象です。jq のフィルタ `'.key'` のような語幹の無い語や、`credentials-manager` のような語の一部の一致は対象外です。
シェルのトークンのうち、`$` か `.` で始まりパスの区切りを含まないもの（`$_.Key` / `$cfg.pem` / jq のパス `.data.key` 等）は、変数のプロパティや jq のパスとみなし、拡張子では判定しません。
Grep の `glob`・Glob の `pattern` の波括弧（`**/{.env,*.pem}` / `*.{pem,key}`）は展開し、候補ごとに判定します（候補が 64 個を超えるパターンは、判定を打ち切って通知します）。
Windows ではファイル名の末尾の空白・ピリオドと `::$DATA` が無視されるため、`.env.` / `.env::$DATA` も `.env` として判定します。
通知文に入れるファイル名は 48 文字までにし、英数字と `. _ - * ? ~ @ +` 以外の文字を `_` に置き換えます（名前に書いた文がそのままモデルに届かないようにするため）。
判定するトークンは 256 個までで、手掛かりの語を含むトークンがそれを超えるコマンドは、判定を打ち切って「認証情報系ファイルらしい名前を多数含むコマンド」として通知します（timeout を超えて無言で欠落しないようにするため）。
4 KB を超えるパス（シェルのトークン、ファイル系ツールのパス、Grep / Glob の対象）は、中身を判定せずに「認証情報系ファイルかを判定できないパス」として通知します（判定に時間がかかる一方、黙って除外すると長いパスで判定を逃れられるため）。

#### 5. シークレットパターン（`Bash` / `PowerShell` の command、`Write` / `Edit` 等のコンテンツ）

```text
sk-*  ghp_*  gho_*  ghu_*  ghs_*  ghr_*
xoxb-*  xoxp-*  xoxa-*  xoxr-*  xoxs-*
AKIA<16>  AIza<35>  glpat-*  eyJ*.*.*  Bearer ...
Basic <base64>  -----BEGIN ... PRIVATE KEY-----
```

パターンは UserPromptSubmit のフックと共通です（`references/scripts/hooks/lib/credential_patterns.sh`）。
1〜3 行目の既知のトークン形式は、単語の途中（`task-management-system` 等の語に含まれる部分）には一致しません（左側に英数字・`_`・`-` が無いことを条件にしています）。
ただし、エスケープした改行・タブ（`\n` / PowerShell の `` `n `` 等）と URL エンコード（`%3D` 等）の直後は、英数字が続いていても境界として扱います。
PEM は PGP の秘密鍵（先頭行が `PRIVATE KEY BLOCK` で終わるもの）も対象です。
`Write` / `Edit` 等は `tool_input` の文字列（内容・置換の前後・パス）だけを照合し、`cwd` などのメタデータは照合しません。

ローカル完結の `ls` / `cat` / `git status` / `mkdir` / `grep`、`Get-ChildItem` / `Get-Location` / `Get-Process` 等（PowerShell の文字コード設定のプリフィクスを含む）、無関係な `Read`/`Write` ファイル（`README.md` `package.json` 等）は通知対象外です。

#### 既知の制約

検出はコマンド文字列のパターン照合による念押しであり、次の誤検出・検出漏れがあります（回帰テストの「既知の制約」に同じ例を記録しています）。

| 種別 | 例 |
|-----|---|
| 誤検出 | 変数名のキーワードへの部分一致（`GIT_AUTHOR_NAME` の `AUTH`、`API_BASE_URL` の `API`）。PowerShell で、パスの末尾の要素や引用符の中の語が CLI 名と一致するもの（`Set-Location .\terraform` / `Write-Output "HTTP status: 200"`）。引用符の中の `IRM` / `IWR` という語。`Basic` の直後に英数字だけの長い語（16 文字以上）が続くもの（認証スキーム名のような識別子）。シェルで `.env` 等を指すトークンは、操作の種類によらず通知される（`echo ".env" >> .gitignore` 等）。語幹のあるプロパティやソート指定が拡張子と一致するもの（`console.log(c.key)` / `--order=name.asc`） |
| 検出漏れ | `Bash` でのパス付きの起動（`/usr/bin/curl`）。`-Name` を `-Path Env:` より前に書く `New-Item`。レジストリ（`HKCU:\Environment`）経由の環境変数の設定。`git` 経由の通信。値の表示（`Write-Output $env:FOO_TOKEN`）。文字列の連結や `-EncodedCommand` 等で難読化したコマンド。シェルで、パスを付けずに書いた `.` で始まる鍵ファイル（`cat .server.key`。jq のパスと区別できない）。シェルの波括弧（`cat {config,secrets}.json`。展開せずに区切りとして扱う）。`~/.aws` の `credentials` / `config` 以外のファイル（`~/.aws/sso/cache/*.json` 等） |

フックはツールの実行を止めません。通知がモデルに届くのは、通知の対象となったツール呼び出しの後です。
判定には、対象のツールの呼び出しごとに 1 回あたり約 0.2〜0.3 秒かかります（Windows の Git Bash での計測）。

大きな入力でも `hooks.json` の `timeout`（10 秒）以内に判定を終えるよう、次のように扱います（3 MB の入力で約 1〜3.5 秒。同じ環境での計測）。

| 入力 | 扱い |
|-----|------|
| `Write` / `Edit` 等のコンテンツ、ユーザープロンプト（256 KB 超） | grep でまとめて照合する（末尾まで照合し、検出漏れは生じない） |
| `Bash` / `PowerShell` のコマンド（256 KB 超） | 先頭 256 KB を照合し、そこで何も見つからなければ「全体を照合できないコマンド」として通知する |
| 4 KB を超えるパス・手掛かりの語を含むトークンが 256 個を超えるコマンド | 4. の説明のとおり、判定を打ち切って通知する |

### UserPromptSubmit — ユーザー入力に含まれるシークレットの保存提案

ユーザーがプロンプトに sk-* / ghp_* / xoxb-* / AKIA / AIza / glpat- / JWT / Bearer / Basic / PEM 秘密鍵等のパターンを含めた瞬間に検出し、Claude に対し「`credentials-reader` を最優先起動 → マスキング + 既存照合 + 保存提案 → 承諾時のみ `credentials-manager` に引き継ぎ保存」を実施するよう通知します。

会話中で平文の認証情報がそのまま復唱されることを防ぎ、保存ファイル経由で安全に扱えるようにします。

### フックが起動を指示するスキル

`additionalContext` で Claude に最優先起動を指示する対象は、参照に特化した軽量な **`credentials-reader`** です。
保存・編集・削除などの書き込みが必要な場合だけ、`credentials-manager`（save / retrieve / list / delete・自動マッチ・運用・セキュリティの全体）に引き継ぎます。

参照のみで完結するケース（自動マッチ・一覧・取得）が多くを占めるため、フック起動時に読み込むコンテキストが抑えられます。

### フックを変更する場合

検出パターンや `hooks.json` の matcher を変更したら、回帰テストを実行してください（`bash` と `jq` が必要です。約 2〜3 分かかります）。

```bash
bash references/scripts/hooks/tests/test_hooks.sh   # プラグインのルートで実行
```

Windows では Git Bash で実行してください（PowerShell から `bash` と呼ぶと、WSL の bash に解決されることがあります）。

対象のツール名は、`hooks.json` の matcher とスクリプトの `case` 分岐の 2 か所に書かれています。片方だけを直しても検査は働かないため、回帰テストは matcher の一致と、分岐ごとの通知の両方を検証します。
回帰テストは、空白や改行の多い大きな入力（300 KB〜1 MB）を `hooks.json` の `timeout` の 8 割以内で判定できることと、README・ルールテンプレートに書かれたツール名が matcher と一致することも確かめます。`timeout` を超えるとフックは打ち切られ、通知は出ません。

### フックを無効化したい場合

利用者プロジェクトの `.claude/settings.local.json` で hook を無効化、またはプラグイン本体をアンインストールしてください（プラグインスキル単体運用は SKILL.md の description で引き続き機能します）。

## 対話 UI: `/credentials-manager:manage`

Claude Code の `/config` コマンドのように、`AskUserQuestion` を使って操作メニューを順次提示し、保存済み認証情報を対話的に管理できる設定 UI です。

```text
/credentials-manager:manage              # メニューUI起動
/credentials-manager:manage list         # 一覧表示を直接実行
/credentials-manager:manage add          # 新規保存を直接実行
/credentials-manager:manage update       # 編集を直接実行
/credentials-manager:manage delete       # 削除を直接実行
/credentials-manager:manage repair       # JSON 破損時の修復を直接実行
```

メニューモードでは「一覧／追加／編集／削除／終了」を順次選択でき、`credentials-reader`（一覧）と `credentials-manager`（追加・編集・削除・修復）を背後で呼び分けます。

詳細は [`commands/manage.md`](commands/manage.md) を参照してください。

## 認証情報ファイルの保存先

セッション開始時のワーキングディレクトリに応じて、以下の優先順位で解決されます。

| 優先順位 | 条件 | パス |
|---------|------|------|
| 1（優先） | 現在のディレクトリ（または祖先）に `.git` がある | `<repo_root>/.claude/.local/plugins/credentials-manager/credentials.json` |
| 2（フォールバック） | リポジトリ外での作業 | `~/.claude/.local/plugins/credentials-manager/credentials.json` |

| インストール形態 | 解決パス |
|---------------|---------|
| ユーザー単位（user）— リポジトリ外で利用 | `~/.claude/.local/plugins/credentials-manager/credentials.json` |
| プロジェクト単位（project）— リポジトリ内で利用 | `<repo_root>/.claude/.local/plugins/credentials-manager/credentials.json` |
| ローカル単位（local） | プロジェクト単位と同様 |

プロジェクト単位の認証情報はそのリポジトリ専用となり、他プロジェクトには共有されません。リポジトリ内に保存する場合は `.claude/.local/` を `.gitignore` に登録してください（未登録時はスキルが警告します）。

## ファイル構成

```text
plugins/credentials-manager/
├── .claude-plugin/
│   └── plugin.json
├── README.md                                          # このファイル
├── LICENSE                                            # MIT
├── commands/
│   └── manage.md                                      # /credentials-manager:manage
├── hooks/
│   └── hooks.json                                     # SessionStart / PreToolUse / UserPromptSubmit フック登録
├── references/
│   ├── scripts/
│   │   └── hooks/
│   │       ├── lib/
│   │       │   ├── credential_patterns.sh             # 秘密情報のパターン（PreToolUse / UserPromptSubmit で共通）
│   │       │   └── credential_files.sh                # 認証情報系ファイルの判定とコマンドのトークン分割（PreToolUse）
│   │       ├── install_rule_template.sh               # SessionStart：テンプレート配置
│   │       ├── preempt_credentials_check.sh           # PreToolUse：reader 起動指示
│   │       ├── detect_credentials_in_prompt.sh       # UserPromptSubmit：マスキング + reader 起動指示
│   │       └── tests/
│   │           └── test_hooks.sh                      # 同梱フックと hooks.json の回帰テスト
│   └── templates/
│       └── rules/
│           └── security/
│               └── credentials-management.md          # 最重要ルールのテンプレート（責務分離反映）
└── skills/
    ├── credentials-reader/                            # 参照系特化スキル（軽量）
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── references/
    │   │   ├── retrieve.md                            # 取得・一覧の操作仕様
    │   │   ├── auto-match.md                          # URL 自動マッチ仕様
    │   │   ├── handoff.md                             # credentials-manager への引き継ぎ仕様
    │   │   └── security.md                            # セキュリティ注意（参照系）
    │   └── evals/
    │       ├── README.md
    │       └── case-01〜16                            # 参照系の動作分岐（11〜16 は自動適用しない一致の境界）
    └── credentials-manager/                           # 書き込み系特化スキル
        ├── SKILL.md
        ├── README.md
        ├── references/
        │   ├── operations.md                          # save / update / delete / repair の詳細仕様
        │   └── security.md                            # セキュリティ注意（書き込み系）
        └── evals/
            ├── README.md
            ├── case-01_save_with_url.md
            ├── case-07_delete_with_confirm.md
            ├── case-08_non_interactive.md
            ├── case-11_json_parse_error.md            # repair（reader 引き継ぎ）
            ├── case-12_user_scoped_save.md
            ├── case-13_gitignore_warning.md
            ├── case-14〜25                            # 同梱フック動作の評価
            ├── case-26_update_with_confirm.md         # update
            ├── case-27_manage_command.md              # /credentials-manager:manage 経由
            ├── case-28_handoff_from_reader.md         # reader 引き継ぎ受け入れ
            └── case-29〜55                            # 同梱フック動作の評価（PreToolUse の環境変数・PowerShell 等、UserPromptSubmit の PEM、SessionStart の自己診断）
```

## 技術スタック・アーキテクチャ

### 内部構成

- 2 スキル（`credentials-reader` / `credentials-manager`）
- 1 コマンド（`/credentials-manager:manage`）
- 3 フック（SessionStart / PreToolUse / UserPromptSubmit）
- ストアファイル: JSON（`credentials.json`）
- 保存先: スコープ自動解決（リポジトリ内なら `<repo>/.claude/.local/plugins/credentials-manager/`、それ以外は `~/.claude/.local/plugins/credentials-manager/`）

### 採用技術

- Markdown / JSON / Bash（フックは `bash` と `jq` で動作）
- Claude Code Skills API（`SKILL.md` の description ベースの自動トリガー判定を活用）
- Claude Code Hooks API（SessionStart / PreToolUse / UserPromptSubmit）
- Claude Code Commands API（`/credentials-manager:manage`）
- `AskUserQuestion`（対話メニュー UI）

### 設計上の特徴

- **責務分離**: 参照系と書き込み系を別スキルに分離。フック経由の起動時に軽量な `credentials-reader` のみが読み込まれ、コンテキスト消費を抑制
- **対話 UI コマンド**: `/credentials-manager:manage` で `/config` 風のメニュー UI を提供
- **グローバルルール非依存**: 各 SKILL.md description に URL/API アクセス時の自動起動条件を記述しているため、利用者環境にグローバルルールが無くても自動的に認証情報問い合わせ先として機能する
- **install スコープ自動解決**: ワーキングディレクトリに `.git` があればプロジェクト単位、無ければユーザー単位を自動選択

## セキュリティ注意

- 認証情報はローカルファイルに **平文** で保存される。本番秘匿情報の運用には適さない。
- 値は会話出力では常にマスクされる（フル値は表示しない）。
- リポジトリ内に保存される場合、`.claude/.local/` が `.gitignore` に登録されていることを確認する。
- `credentials.json` をコミットしてはならない。
- `credentials-reader` → `credentials-manager` 引き継ぎ時はマスク済み情報のみが渡され、フル値はユーザに再入力させる仕様。

詳細は `skills/credentials-reader/references/security.md` および `skills/credentials-manager/references/security.md` を参照してください。

## ライセンス

[MIT License](LICENSE) の下で配布されています。
