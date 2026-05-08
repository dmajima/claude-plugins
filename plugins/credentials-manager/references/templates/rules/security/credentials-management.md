# Credentials Management (MANDATORY / HIGHEST PRIORITY)

認証情報（API キー・トークン・パスワード・秘密鍵・Bearer・OAuth・Basic 認証等）が
関係し得るあらゆる処理において、以下の **責務分離されたスキル群を最優先で利用すること**。
本ルールは Claude Code セッション中で **常に最高優先度** で適用される。

| スキル / コマンド | 責務 |
|----------------|------|
| `credentials-reader` | 取得（retrieve）／一覧（list、参照目的）／URL 自動マッチ／プロアクティブ検出 |
| `credentials-manager` | 追加（save）／編集（update）／削除（delete）／修復（repair） |
| `/credentials-manager:manage` | 上記両スキルを統合した対話メニュー UI |

このファイルは [`credentials-manager`](https://github.com/dmajima/claude-plugins) プラグインの
SessionStart フックによって自動配置されるテンプレートである。
内容を編集してプロジェクト固有の補足を追加してもよいが、最重要ルールとしての
位置付けは維持すること。

---

## 1. 適用トリガー（このルールが発動する条件）

以下の **いずれか** が発生する瞬間に、本ルールを必ず確認・適用する。

### 1.1 明示要求（ユーザの指示）

| トリガー | 例 | 起動先 |
|---------|---|------|
| 認証情報の取得・一覧（参照） | 「保存済み認証情報を一覧」「先ほどのキーで API を叩いて」 | `credentials-reader` |
| 認証情報の追加・編集・削除（書き込み） | 「OpenAI の API キーを保存して」「openai-api-key を削除」 | `credentials-manager` |
| 対話的に管理 UI を起動 | `/credentials-manager:manage` | コマンド経由で両スキルを呼び分け |
| URL / API エンドポイントへのアクセス | 「`https://api.openai.com/...` から取得」 | `credentials-reader`（必要時 manager 引き継ぎ） |
| 外部通信を伴うコマンドの実行 | `curl`, `wget`, `gh api`, `Invoke-RestMethod` | 同上 |
| 外部通信を伴うコードの作成・実行 | Python `requests` / `httpx`, Node `fetch` / `axios` | 同上 |
| `WebFetch` / `WebSearch` 等の外部取得ツール利用 | 「このサイトを見て」「これを取得して」 | 同上 |
| MCP サーバ・外部 API への接続 | `mcp__*` ツール呼び出し | 同上 |

### 1.2 暗黙トリガー（ユーザ入力に含まれるシークレット）

会話中にユーザが認証情報らしい文字列を貼り付けた場合（プラグイン同梱の
`UserPromptSubmit` フックでも検出される）。

| パターン | 種別 |
|---------|------|
| `sk-...` (16+ 文字) | OpenAI API Key |
| `ghp_...` / `gho_...` / `ghu_...` / `ghs_...` / `ghr_...` | GitHub Personal/OAuth/User/Server/Refresh Token |
| `xoxb-...` / `xoxp-...` / `xoxa-...` / `xoxr-...` / `xoxs-...` | Slack Token |
| `AKIA<16 文字>` | AWS Access Key ID |
| `AIza<35 文字>` | Google API Key |
| `glpat-...` | GitLab Personal Access Token |
| `eyJ<...>.<...>.<...>` | JWT |
| `Bearer ...` (16+ 文字) | HTTP Bearer Token |
| `Basic <base64>` | HTTP Basic 認証ヘッダ |
| `-----BEGIN ... PRIVATE KEY-----` | PEM 形式秘密鍵 |

このパターン検出時は **`credentials-reader` を起動** してマスキング・既存照合・保存提案を行う。
ユーザが保存承諾した場合のみ `credentials-manager` に引き継ぐ。

### 1.3 暗黙トリガー（ファイル / コマンドに含まれる認証情報）

プラグイン同梱の `PreToolUse` フックは下記を検出して通知する。

| ツール / 条件 | 対象 |
|------------|------|
| `WebFetch` / `WebSearch` / `mcp__*` | 常に対象 |
| `Bash` の `command` に外部通信 / IaC / シークレット管理コマンド | `curl` / `wget` / `gh` / `ssh` / `scp` / `sftp` / `rsync` / `aws` / `az` / `gcloud` / `kubectl` / `doctl` / `heroku` / `firebase` / `vercel` / `netlify` / `docker` / `podman` / `psql` / `mysql` / `mongosh` / `redis-cli` / `terraform` / `tofu` / `ansible` / `helm` / `pulumi` / `packer` / `vault` / `op` / `bw` / `Invoke-WebRequest` / `Invoke-RestMethod` / `iwr` / `irm` |
| `Bash` の `command` で認証情報らしい環境変数を設定 | `export FOO_TOKEN=...` / `set FOO_KEY=...` 等 |
| `Bash` / `Write` / `Edit` / `MultiEdit` / `NotebookEdit` のコンテンツにシークレットパターン | 1.2 のパターンを含む |
| `Read` / `Write` / `Edit` / `MultiEdit` / `NotebookEdit` が下記ファイルを対象とする | 認証情報系ファイル（次表） |

認証情報系ファイル（`PreToolUse` で検出する `file_path`）:

| 種別 | 対象ファイル |
|-----|------------|
| 環境変数定義 | `.env` / `.env.<name>`（`.env.example` `.sample` `.template` `.dist` `.test` は除外） |
| 認証情報ストア | `credentials.json` / `credentials.yml` / `credentials.yaml` / `credential.json` / `secrets.json` / `secrets.yml` / `secrets.yaml` / `secret.json` |
| ツール設定 | `.npmrc` / `.netrc` / `.pgpass` / `.git-credentials` / `.dockercfg` |
| 秘密鍵 (SSH) | `id_rsa` / `id_dsa` / `id_ecdsa` / `id_ed25519` / `id_xmss` |
| クラウド認証 | `~/.aws/credentials` / `~/.aws/config` / `~/.docker/config.json` / `~/.kube/config` / `kubeconfig` / `serviceAccountKey.json` / `service-account.json` / `application_default_credentials.json` / `gcloud-credentials.json` |
| ディレクトリ全体 | `~/.ssh/*` / `~/.gnupg/*` |
| 拡張子 | `*.pem` / `*.key` / `*.p12` / `*.pfx` / `*.jks` / `*.keystore` / `*.crt` / `*.cer` / `*.der` / `*.asc` / `*.gpg` |

これらを検出した場合は **`credentials-reader` を最優先起動** し、書き込みが必要な場合のみ
`credentials-manager` に引き継ぐ。

---

## 2. 厳守ルール

### 2.1 最優先での起動（MANDATORY）

上記トリガーが発生した時点で、**他のスキル・他のツール呼び出しに先立って**
適切なスキルを起動すること。

| 状況 | 起動するスキル | 動作 |
|-----|-------------|------|
| 参照のみ（保存済み照合・自動適用） | `credentials-reader` | マッチ件数に応じた挙動 |
| 保存済み認証情報が **1 件マッチ** | `credentials-reader` | 自動適用し、ユーザに「`<name>` (`****`) を `<domain>` に自動適用しました」と通知 |
| 保存済み認証情報が **複数件マッチ** | `credentials-reader` | `AskUserQuestion` でどれを使うか確認（マスク済み値を表示） |
| 保存済み認証情報が **0 件** | `credentials-reader` | 「`<domain>` 用の認証情報は保存されていません。提供しますか？」と確認 → 承諾なら `credentials-manager` に引き継ぎ |
| 書き込み（追加・編集・削除・修復） | `credentials-manager` | 該当フローを実行 |
| 対話メニューでの管理 | `/credentials-manager:manage` | メニュー UI で両スキルを呼び分け |

### 2.2 認証情報の取り扱い

- 認証情報の **フル値を会話出力・ログ・コミットメッセージに出してはならない**（常にマスクする）
- マスク形式: 先頭 4 文字 + `****` + 末尾 4 文字（例: `sk-p****f456`）。値長が 8 文字以下なら全マスク `****`
- `credentials.json` をリポジトリにコミットしてはならない（`.gitignore` 登録を確認）
- 認証情報を含む可能性のある文字列をユーザに **そのまま読み返さない**
- `credentials-reader` → `credentials-manager` 引き継ぎ時はマスク済み情報のみ渡し、フル値はユーザに再入力させる

### 2.3 スキル起動の省略禁止

以下のいずれの理由でも、本ルールの適用を **省略してはならない**。

- 「短い 1 行コマンドだから」
- 「ローカルホストへのアクセスだから」（公開ドメインの可能性確認後に判断）
- 「ユーザが認証情報を明示していないから」
- 「グローバルルールが他にないから」

---

## 3. credentials-manager プラグインの構成

`credentials-manager` プラグインは三層で本ルールの実効性を担保する。

| 層 | 機構 | 役割 |
|----|------|------|
| 1 | `credentials-reader` / `credentials-manager` SKILL.md `description` | URL / API アクセス時の自動起動条件を AI トリガー判定で常に参照させる（責務分離） |
| 2 | `PreToolUse` / `UserPromptSubmit` フック | 上記表のパターン検出時、`additionalContext` で Claude に **`credentials-reader` の最優先起動** を指示（書き込みは reader が manager に引き継ぐ） |
| 3 | 本ルール (`rules/security/credentials-management.md`) | グローバルルール体系上での **最優先度の明示**、プロジェクト固有補足の土台 |

フック（層 2）は `PreToolUse` がツール実行前、`UserPromptSubmit` がユーザ入力受信後に
発火するため、層 1 の description が AI トリガー判定で読み飛ばされた場合の **冗長な保険**
として機能する。本ルール（層 3）は、フック非対応環境への移行や、ルール体系として
明示的に最優先度を宣言する目的で配置される。

参照系を `credentials-reader` に絞ることでフック起動時に読み込まれるコンテキストが軽量化され、
書き込みが必要な場合のみ `credentials-manager` の本体ドキュメントが読み込まれる設計である。

---

## 4. 動作モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| 引数で対象認証情報名・値・URL が全指定 / `--non-interactive` 相当 | 非対話 | 確認をスキップしデフォルト値で進行 |
| 上記以外（多くは自然言語入力） | 対話 | 不足パラメータを `AskUserQuestion` でユーザに確認 |

---

## 5. 認証情報ファイルの保存先（参考）

`credentials-manager` スキルが解決するパスは以下の通り（`credentials-reader` も同じパスを参照する）。

| 優先順位 | 条件 | パス |
|---------|------|------|
| 1（優先） | 現在のディレクトリまたは祖先に `.git` が存在 | `<repo_root>/.claude/.local/plugins/credentials-manager/credentials.json` |
| 2（フォールバック） | リポジトリ外での作業 | `~/.claude/.local/plugins/credentials-manager/credentials.json` |

---

## 6. チェックリスト（認証情報・URL アクセス時に必ず確認）

- [ ] 参照系の場合 `credentials-reader` を **他のツール呼び出しに先立って** 起動したか
- [ ] 書き込みが必要な場合 `credentials-manager` に正しく引き継いだか
- [ ] 対象 URL / ドメインに対する保存済み認証情報を照合したか
- [ ] マッチ結果（0 件 / 1 件 / 複数件）に応じた適切な動作を行ったか
- [ ] 認証情報のフル値を会話出力していないか
- [ ] 新規保存時、`.claude/.local/` が `.gitignore` に登録されているか確認したか
- [ ] 引き継ぎ時にフル値をメインコンテキストに残していないか

---

## 7. 禁止事項（再掲）

- 認証情報のフル値を会話出力・ログ・コミットメッセージに出すこと
- `credentials.json` をリポジトリにコミットすること
- 外部通信ツール（`WebFetch` / `Bash`(curl/wget/gh) / `mcp__*` 等）を呼び出す前に
  `credentials-reader` での認証情報照合を省略すること
- 「ローカルホストアクセス」「短いコマンド」等を理由に本ルールを省略すること
- 参照系（retrieve / list / auto-match）に `credentials-manager` 全体を起動して不要なコンテキストを読み込むこと（`credentials-reader` を使う）

---

## 8. 関連ルール・参照

- [`credentials-reader` プラグイン SKILL.md](../../../plugins/credentials-manager/skills/credentials-reader/SKILL.md)
- [`credentials-manager` プラグイン SKILL.md](../../../plugins/credentials-manager/skills/credentials-manager/SKILL.md)
- [`credentials-manager` プラグイン README.md](../../../plugins/credentials-manager/README.md)
- [`/credentials-manager:manage` コマンド](../../../plugins/credentials-manager/commands/manage.md)
