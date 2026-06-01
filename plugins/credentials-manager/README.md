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
| `install_rule_template.sh` | フック (SessionStart) | スコープ判定（user / project）に応じて最重要ルール `credentials-management.md` を `.claude/rules/security/` 配下へ自動配置（既存ファイルは温存）。Bash 通常運用 / `install_rule_template.sh` は PowerShell フォールバック |
| `preempt_credentials_check.sh` | フック (PreToolUse) | 外部通信・認証情報系ファイル・コンテンツ内シークレット検出時に Claude へ「`credentials-reader` を最優先起動」と注意喚起。Bash 通常運用 / `preempt_credentials_check.sh` は PowerShell フォールバック |
| `detect_credentials_in_prompt.sh` | フック (UserPromptSubmit) | ユーザー入力にシークレットパターン検出時、Claude へ「マスキング + `credentials-reader` 起動 + 必要時 `credentials-manager` 引き継ぎ」と通知。Bash 通常運用 / `detect_credentials_in_prompt.sh` は PowerShell フォールバック |

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
git clone https://github.com/dmajima/claude-plugins ~/claude-plugins

# 2. リリースタグ（推奨）またはブランチに切替
cd ~/claude-plugins
git checkout v2.0.0   # 推奨: 検証済みリリースタグ
# または: git checkout main   # 最新追従
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
- 配置時のみ `additionalContext` で Claude に通知します
- 配置後は `CLAUDE.md` から `rules/security/credentials-management.md` を参照する 1 行を追記してください（既存運用と整合）

### PreToolUse — 認証情報を扱い得る全ツール呼び出しの注意喚起

以下のいずれかに該当するツール呼び出しを検出した時点で、`hookSpecificOutput.additionalContext` を介して Claude に「`credentials-reader` を最優先起動して照合し、書き込みが必要な場合のみ `credentials-manager` に引き継ぐ」と通知します。

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

ユーザーがプロンプトに sk-* / ghp_* / xoxb-* / AKIA / AIza / glpat- / JWT / Bearer / Basic / PEM 秘密鍵等のパターンを含めた瞬間に検出し、Claude に対し「`credentials-reader` を最優先起動 → マスキング + 既存照合 + 保存提案 → 承諾時のみ `credentials-manager` に引き継ぎ保存」を実施するよう通知します。

会話中で平文の認証情報がそのまま復唱されることを防ぎ、保存ファイル経由で安全に扱えるようにします。

### フックの軽量化（v2.0.0 から）

`additionalContext` で Claude に最優先起動を指示する対象が **`credentials-reader`** に絞られたことで、フック起動時のコンテキスト読み込み量が大幅に減少しました。

- v1 系: フックが `credentials-manager` 全体（save / retrieve / list / delete + auto-match + operations + security）を起動指示
- v2 系: フックが `credentials-reader` のみ（軽量・参照特化）を起動指示。書き込みが必要な場合のみ `credentials-manager` に引き継ぐ

参照のみで完結するケース（自動マッチ・一覧・取得）が多くを占めるため、平均的なフック起動時のコンテキスト消費が抑えられます。

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
│   │       ├── install_rule_template.sh               # SessionStart：テンプレート配置
│   │       ├── preempt_credentials_check.sh           # PreToolUse：reader 起動指示
│   │       └── detect_credentials_in_prompt.sh       # UserPromptSubmit：マスキング + reader 起動指示
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
    │       └── case-01〜10                            # 参照系の動作分岐
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
            └── case-28_handoff_from_reader.md         # reader 引き継ぎ受け入れ
```

## 技術スタック・アーキテクチャ

### 内部構成

- 2 スキル（`credentials-reader` / `credentials-manager`）
- 1 コマンド（`/credentials-manager:manage`）
- 3 フック（SessionStart / PreToolUse / UserPromptSubmit）
- ストアファイル: JSON（`credentials.json`）
- 保存先: スコープ自動解決（リポジトリ内なら `<repo>/.claude/.local/plugins/credentials-manager/`、それ以外は `~/.claude/.local/plugins/credentials-manager/`）

### 採用技術

- Markdown / JSON / PowerShell
- Claude Code Skills API（`SKILL.md` の description ベースの自動トリガー判定を活用）
- Claude Code Hooks API（SessionStart / PreToolUse / UserPromptSubmit）
- Claude Code Commands API（`/credentials-manager:manage`）
- `AskUserQuestion`（対話メニュー UI）

### 設計上の特徴

- **責務分離（v2.0.0 〜）**: 参照系と書き込み系を別スキルに分離。フック経由の起動時に軽量な `credentials-reader` のみが読み込まれ、コンテキスト消費を抑制
- **対話 UI コマンド（v2.0.0 〜）**: `/credentials-manager:manage` で `/config` 風のメニュー UI を提供
- **グローバルルール非依存**: 各 SKILL.md description に URL/API アクセス時の自動起動条件を記述しているため、利用者環境にグローバルルールが無くても自動的に認証情報問い合わせ先として機能する
- **install スコープ自動解決**: ワーキングディレクトリに `.git` があればプロジェクト単位、無ければユーザー単位を自動選択

## セキュリティ注意

- 認証情報はローカルファイルに **平文** で保存される。本番秘匿情報の運用には適さない。
- 値は会話出力では常にマスクされる（フル値は表示しない）。
- リポジトリ内に保存される場合、`.claude/.local/` が `.gitignore` に登録されていることを確認する。
- `credentials.json` をコミットしてはならない。
- `credentials-reader` → `credentials-manager` 引き継ぎ時はマスク済み情報のみが渡され、フル値はユーザに再入力させる仕様。

詳細は `skills/credentials-reader/references/security.md` および `skills/credentials-manager/references/security.md` を参照してください。

## PowerShell フォールバック

通常運用は Bash 経路（`.sh` フック）を使用します。Git Bash の初期化不調等で Bash 経路が機能しない場合、PowerShell 経路に手動切替できます。

```bash
# Bash → PowerShell へ切替
cp references/hooks-fallback/hooks.sh.json hooks/hooks.json
# Claude Code を再起動
```

Bash 版（`*.sh`）と PowerShell 版（`*.ps1`）は、同じ入力（stdin JSON）に対して同じ JSON 出力・exit code を返すよう実装されています。詳細手順は `references/hooks-fallback/README.md` 参照。

## ライセンス

[MIT License](LICENSE) の下で配布されています。
