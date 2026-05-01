# credentials-manager

Claude Code セッションをまたいで認証情報（API キー・トークン・パスワード等）を管理するプラグイン。URL / ドメイン関連付けによる自動適用に対応する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。各スキルの動作本体は `skills/credentials-manager/SKILL.md` および `references/` 配下を参照してください。

## 提供機能

| 機能 | 種別 | 説明 |
|-----|------|------|
| `credentials-manager` | スキル | 認証情報の保存・取得・一覧・削除、URL/ドメインからの自動マッチ・自動適用 |
| `install_rule_template.sh` | フック (SessionStart) | スコープ判定（user / project）に応じて最重要ルール `credentials-management.md` を `.claude/rules/security/` 配下へ自動配置（既存ファイルは温存） |
| `preempt_credentials_check.sh` | フック (PreToolUse) | `WebFetch` / `WebSearch` / `mcp__*` / `Bash`（外部通信・認証付きクライアント・シークレット埋め込み・認証情報環境変数 export）/ `Read` / `Write` / `Edit` / `MultiEdit` / `NotebookEdit`（認証情報系ファイル・コンテンツ内シークレット）の実行前に Claude へ「`credentials-manager` を最優先で起動」と注意喚起 |
| `detect_credentials_in_prompt.sh` | フック (UserPromptSubmit) | ユーザー入力に sk-* / ghp_* / xoxb-* / Bearer / Basic / JWT / PEM 秘密鍵等のシークレットパターンが含まれる場合、Claude へ「保存提案＋マスキング処理を最優先で実施」と通知 |

## 導入手順

### 前提

- Claude Code がインストール済み
- 依存関係なし（外部プラグイン・外部 CLI に依存しない）

### A. マーケットプレイス経由インストール（推奨）

```text
/plugin marketplace add https://github.com/dmajima/claude-plugins
/plugin install credentials-manager@dmajima-claude-plugins
```

### B. ローカル複製してインストール（オフライン・企業内環境向け）

公開マーケットプレイスにアクセスできない環境では、リポジトリをローカルに複製してから登録します。

```bash
# 1. リポジトリを複製
git clone https://github.com/dmajima/claude-plugins <local-path>

# 2. リリースタグ（推奨）またはブランチに切替
cd <local-path>
git checkout v1.0.0   # 推奨: 検証済みリリースタグ
# または: git checkout main   # 最新追従
```

```text
# 3. ローカルパスでマーケットプレイスを登録
/plugin marketplace add <local-path>

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

スキルが起動して `credentials.json`（不在時は空ストア表示）の内容を返せば導入成功です。

## 使い方

### 最小例

ユーザ:
> OpenAI の API キー `sk-proj-abc123def456` を保存して

Claude（要約）:
> `openai-api-key` として保存しました（api_key）。値: `sk-p****f456` 保存先: `<repo>/.claude/.local/plugins/credentials-manager/credentials.json`

### 応用例

| 目的 | フレーズ | 動作 |
|-----|---------|------|
| URL アクセス時に自動適用 | 「`https://api.openai.com/v1/models` から取得して」 | 保存済み認証情報を URL/ドメインで自動マッチして適用 |
| プロアクティブ検出 | 「キーは `ghp_xxxxxxxx`」 | 認証情報パターン検出 → 保存提案 |
| 削除 | 「`openai-api-key` を削除して」 | 対象エントリを削除（要確認） |
| 一覧 | 「保存してある認証情報を一覧表示」 | 表形式でマスク済み値を表示 |

### URL アクセス時の自動起動について

本スキルは **明示要求がなくても、ユーザが URL / API エンドポイント / WebFetch / curl / 外部サービス通信を依頼した時点で自動起動** します。グローバルルール `~/.claude/rules/security/credentials-management.md` の有無に関わらず、SKILL.md の description が AI トリガー判定で参照されるため、利用者環境にグローバルルールが無くても問い合わせ先として機能します。

さらに本プラグインは下記 2 つのフックで強制力を多重化しています。

## 自動化機構（hooks）

### SessionStart — 最重要ルールテンプレートの自動配置

セッション開始時に `${CLAUDE_PLUGIN_ROOT}/templates/rules/security/credentials-management.md` を、プラグインのインストールスコープに応じた以下のディレクトリへコピーします。

| スコープ判定 | 配置先 |
|------------|-------|
| `${CLAUDE_PLUGIN_ROOT}` が `${HOME}/.claude/` 配下にある（user スコープ） | `${HOME}/.claude/rules/security/credentials-management.md` |
| 上記以外（project / local スコープ） | `${CLAUDE_PROJECT_DIR}/.claude/rules/security/credentials-management.md` |

- 既に同名ファイルが存在する場合は **何もしません**（ユーザーの編集を尊重）
- 配置時のみ `additionalContext` で Claude に通知します
- 配置後は `CLAUDE.md` から `rules/security/credentials-management.md` を参照する 1 行を追記してください（既存運用と整合）

### PreToolUse — 認証情報を扱い得る全ツール呼び出しの注意喚起

以下のいずれかに該当するツール呼び出しを検出した時点で、`hookSpecificOutput.additionalContext` を介して Claude に「`credentials-manager` を最優先で起動して認証情報を照合せよ」と通知します。

#### 1. ツール種別による検出

| ツール / 条件 | 検出 |
|-----------|------|
| `WebFetch` / `WebSearch` | 常に対象 |
| `mcp__*`（任意の MCP サーバ呼び出し） | 常に対象 |
| `Bash` の `command` に対象コマンドを含む | 下記 2 / 3 のいずれか |
| `Read` / `Write` / `Edit` / `MultiEdit` / `NotebookEdit` の `file_path` が認証情報系 | 下記 4 のリストに該当 |
| `Write` / `Edit` / `MultiEdit` / `NotebookEdit` のコンテンツにシークレットパターン | 下記 5 のいずれか |

#### 2. Bash matcher の外部通信 / 認証付きクライアント / IaC / シークレット管理 CLI

```text
curl / wget / http / httpie / aria2c
ssh / scp / sftp / rsync / gh
aws / az / gcloud / kubectl / doctl / heroku / firebase / vercel / netlify
docker / podman / psql / mysql / mongosh / mongo / redis-cli
terraform / tofu / ansible / ansible-playbook / helm / pulumi / packer
vault / op / bw
Invoke-WebRequest / Invoke-RestMethod / iwr / irm
```

#### 3. Bash matcher の認証情報環境変数設定

```text
export FOO_TOKEN=...      / set FOO_KEY=...
export FOO_SECRET=...     / export FOO_PASSWORD=...
export FOO_API_KEY=...    / export FOO_AUTH=...
export FOO_CREDENTIAL=... / export FOO_BEARER=...
```

#### 4. 認証情報系ファイルパス（Read/Write/Edit 等で対象化）

| 種別 | 対象 |
|-----|------|
| 環境変数定義 | `.env` / `.env.<name>`（`.env.example` `.sample` `.template` `.dist` `.test` は除外） |
| 認証情報ストア | `credentials.json` / `credentials.yml` / `secrets.json` / `secret.json` 等 |
| ツール設定 | `.npmrc` / `.netrc` / `.pgpass` / `.git-credentials` / `.dockercfg` |
| 秘密鍵 | `id_rsa` / `id_dsa` / `id_ecdsa` / `id_ed25519` / `id_xmss` |
| クラウド認証 | `~/.aws/credentials` / `~/.aws/config` / `~/.docker/config.json` / `~/.kube/config` / `kubeconfig` / `serviceAccountKey.json` / `application_default_credentials.json` |
| ディレクトリ全体 | `~/.ssh/*` / `~/.gnupg/*` |
| 拡張子 | `*.pem` / `*.key` / `*.p12` / `*.pfx` / `*.jks` / `*.keystore` / `*.crt` / `*.cer` / `*.der` / `*.asc` / `*.gpg` |

#### 5. シークレットパターン（Bash command / Write/Edit content）

```text
sk-*  ghp_*  gho_*  ghu_*  ghs_*  ghr_*
xoxb-*  xoxp-*  xoxa-*  xoxr-*  xoxs-*
AKIA<16>  AIza<35>  glpat-*  eyJ*.*.*  Bearer ...
```

ローカル完結の `ls` / `cat` / `git status` / `mkdir` / `grep` 等、無関係な `Read`/`Write` ファイル（`README.md` `package.json` 等）は通知対象外です。

### UserPromptSubmit — ユーザー入力に含まれるシークレットの保存提案

ユーザーがプロンプトに sk-* / ghp_* / xoxb-* / AKIA / AIza / glpat- / JWT / Bearer / Basic / PEM 秘密鍵等のパターンを含めた瞬間に検出し、Claude に対し「`credentials-manager` で保存提案 → 以降は保存名で参照 → 表示時はマスク値（先頭 4 + `***` + 末尾 4）に置換」を最優先で実施するよう通知します。

会話中で平文の認証情報がそのまま復唱されることを防ぎ、保存ファイル経由で安全に扱えるようにします。

### フックを無効化したい場合

利用者プロジェクトの `.claude/settings.local.json` で hook を無効化、またはプラグイン本体をアンインストールしてください（プラグインスキル単体運用は SKILL.md の description で引き続き機能します）。

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
├── README.md
├── hooks/
│   └── hooks.json                              # SessionStart / PreToolUse フック登録
├── references/
│   └── scripts/
│       └── hooks/
│           ├── install_rule_template.sh        # SessionStart：テンプレート配置
│           ├── preempt_credentials_check.sh    # PreToolUse：認証情報を扱い得る全ツール検出
│           └── detect_credentials_in_prompt.sh # UserPromptSubmit：ユーザー入力のシークレット検出
├── templates/
│   └── rules/
│       └── security/
│           └── credentials-management.md       # 最重要ルールのテンプレート本体
└── skills/
    └── credentials-manager/
        ├── SKILL.md
        ├── README.md
        ├── references/
        │   ├── operations.md
        │   ├── auto-match.md
        │   └── security.md
        └── evals/
            ├── README.md
            ├── case-01_save_with_url.md
            ├── case-02_list_credentials.md
            ├── case-03_proactive_detect.md
            ├── case-04_auto_match_single.md
            ├── case-05_auto_match_multiple.md
            ├── case-06_auto_match_none.md
            ├── case-07_delete_with_confirm.md
            ├── case-08_non_interactive.md
            ├── case-09_retrieve_found.md
            ├── case-10_retrieve_not_found.md
            ├── case-11_json_parse_error.md
            ├── case-12_user_scoped_save.md
            └── case-13_gitignore_warning.md
```

## 技術スタック・アーキテクチャ

### 内部構成

- 1 スキル（`credentials-manager`）
- ストアファイル: JSON（`credentials.json`）
- 保存先: スコープ自動解決（リポジトリ内なら `<repo>/.claude/.local/plugins/credentials-manager/`、それ以外は `~/.claude/.local/plugins/credentials-manager/`）

### 採用技術

- Markdown / JSON
- Claude Code Skills API（`SKILL.md` の description ベースの自動トリガー判定を活用）

### 設計上の特徴

- **グローバルルール非依存**: SKILL.md description に URL/API アクセス時の自動起動条件を記述しているため、利用者環境にグローバルルールが無くても自動的に認証情報問い合わせ先として機能する
- **install スコープ自動解決**: ワーキングディレクトリに `.git` があればプロジェクト単位、無ければユーザー単位を自動選択

## セキュリティ注意

- 認証情報はローカルファイルに **平文** で保存される。本番秘匿情報の運用には適さない。
- 値は会話出力では常にマスクされる（フル値は表示しない）。
- リポジトリ内に保存される場合、`.claude/.local/` が `.gitignore` に登録されていることを確認する。
- `credentials.json` をコミットしてはならない。

詳細は `skills/credentials-manager/references/security.md` を参照してください。
