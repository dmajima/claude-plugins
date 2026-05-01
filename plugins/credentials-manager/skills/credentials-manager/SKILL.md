---
name: credentials-manager
description: Claude Code セッションをまたいで認証情報（APIキー・トークン・パスワード・秘密鍵）を保存・取得・一覧・削除し、URL/ドメイン関連付けで自動適用するスキル。認証情報パターン（sk-/ghp_/xoxb-/AKIA/AIza/JWT/Bearer/PEM 等）、外部通信コマンド（curl/wget/gh/ssh/WebFetch/Invoke-WebRequest/Invoke-RestMethod/iwr/irm/IaC CLI）、認証情報系ファイル（.env/credentials.json/secrets.*/id_rsa/~/.aws/credentials/~/.kube/config/*.pem/*.key 等）の操作を検知。「APIキーを保存して」「保存済み認証情報を一覧」「先ほどのキーで API を叩いて」「.env を読んで」「id_rsa を生成」等で起動する。Use when storing/retrieving auth info, accessing any URL/API endpoint, invoking IaC/secret CLIs (terraform/ansible/vault/op), or reading/writing credential-bearing files. SKIP when no auth info, no outbound network, no credential files (e.g., pure local refactoring).
---

# Credentials Manager

Claude Code セッションをまたいで認証情報を管理し、URL/ドメインに紐づけて自動適用するスキル。認証情報は JSON ファイルに保存し、保存先パスはセッション開始時に自動解決する。

> **description 文字数の例外**: 本スキルは認証情報・外部通信検出のため、認証情報パターン・対象ファイル・対象コマンドの網羅的列挙が AI 自動トリガー精度の確保に必要不可欠であり、誤起動・トリガー漏れが直接的にセキュリティ事故につながる。このため `extension-toolkit/references/description-guide.md` 節 3.3.1 の例外規定（セキュリティクリティカル、上限 700 字）に基づき、通常 300 字上限を超過する設計を採用している。

## 責務

- 認証情報（APIキー・トークン・パスワード・秘密鍵）の保存・取得・一覧・削除
- URL/ドメイン関連付けによる保存済み認証情報の自動マッチ・適用
- API キー風文字列（`sk-...` `ghp_...` `xoxb-...` 等）のプロアクティブ検出と保存提案
- 認証情報値のマスキング表示（先頭4文字 + `***` + 末尾4文字）
- 保存先スコープ（リポジトリ単位 or ユーザー単位）の自動解決

## 責務外（他スキルが担当）

| 業務 | 担当 |
|-----|-----|
| 秘密鍵生成・暗号化・KMS連携・本番秘匿情報運用 | 本スキル対象外（外部 secret manager） |
| マーケットプレイス公開時のシークレットスキャン | `marketplace-publisher`（`extension-toolkit`） |
| `.env` ファイル等の生成・テンプレート化 | スキル外（プロジェクト個別対応） |

## トリガー条件

明示要求トリガー:

- 「OpenAI の API キー `sk-...` を保存して」
- 「GitHub のトークンを覚えておいて」
- 「保存してある認証情報を一覧表示して」
- 「OpenAI キーを削除して」
- 「前に保存した API キーで API を叩いて」

暗黙トリガー（**必須起動**、グローバルルール非依存）:

- ユーザが URL / API エンドポイントへのアクセス（WebFetch・curl・wget・`gh api`・Python requests・Node fetch・任意スクリプト等）を依頼した場合
- ユーザが認証情報の明示提供をしていない場合
- 会話中にユーザが認証情報らしい文字列（`sk-` `ghp_` `xoxb-` `xoxp-` `Bearer ` 等）を貼り付けた場合

このスキルを起動しないケース:

- 認証情報・URL アクセス・外部サービス通信に一切関係しない依頼

## 前提

呼び出し前に以下を解決する:

1. 現在のワーキングディレクトリ（リポジトリ内 or 外）の判定
2. 認証情報ファイルパスの解決（次節「実行フロー」step 1）
3. リポジトリ内の場合は `.claude/.local/` が `.gitignore` に登録されているか

未確定の場合は実行フロー内で順次解決する。

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| 引数で対象認証情報名・値・URLが全指定 / `--non-interactive` 相当 | 非対話 | 確認をスキップしデフォルト値で確定し進行 |
| 上記以外（多くは自然言語入力） | 対話 | 不足パラメータを `AskUserQuestion` でユーザに確認 |

## 実行フロー

### 1. 認証情報ファイルパスを解決

| 優先順位 | 条件 | パス |
|---------|------|------|
| 1（優先） | 現在のディレクトリ（または祖先ディレクトリ）に `.git` がある | `<repo_root>/.claude/.local/plugins/credentials-manager/credentials.json` |
| 2（フォールバック） | リポジトリ外での作業 | `~/.claude/.local/plugins/credentials-manager/credentials.json` |

- 親ディレクトリ（`.claude/.local/plugins/credentials-manager/`）が無ければ作成する
- ファイル不在時は空ストア `{"credentials": {}}` として扱い、初回書き込み時に作成する
- 解決パスは操作のたびに再評価する（セッション中に作業ディレクトリが変わる可能性があるため）
- 解決パスがリポジトリ内の場合、`.claude/.local/` が `.gitignore` に未登録ならユーザに警告してから書き込みを行う

### 2. 操作種別を判定

| ユーザ意図 | 動作分岐 |
|-----------|---------|
| 保存（save） | step 3 |
| 取得（retrieve） | step 4 |
| URL自動マッチ（auto-match） | step 5 |
| 一覧（list） | step 6 |
| 削除（delete） | step 7 |
| プロアクティブ検出（提案） | step 8 |

### 3. 保存（save）

入力: 認証情報の値、識別名（不足時はユーザに確認）、種別、関連 URL/ドメイン（任意）。
出力: マスク済み値 + 保存先パス + 関連 URL/ドメイン + スコープ。
参照: [`references/operations.md`](references/operations.md)

### 4. 取得（retrieve）

入力: 認証情報名（部分一致可）。
出力: フル値（プログラム利用時のみ） / マスク済み値（ユーザ表示時）。
参照: [`references/operations.md`](references/operations.md)

### 5. URL 自動マッチ（auto-match、**暗黙トリガー時の中核動作**）

入力: ユーザのリクエスト URL / ドメイン。
出力: マッチ件数に応じた挙動（自動適用 / 選択依頼 / 認証情報無し通知）。
参照: [`references/auto-match.md`](references/auto-match.md)

| マッチ件数 | 動作 |
|----------|------|
| 1件 | `auth_method` に従って自動適用、ユーザに「保存済み認証情報 `<name>` (`***`) を `<domain>` に自動適用しました」と通知 |
| 複数件 | `AskUserQuestion` でどれを使うか確認（マスク済み値表示） |
| 0件 | ユーザに「`<domain>` 用の認証情報は保存されていません。提供しますか？」と確認 |

### 6. 一覧（list）

入力: なし。
出力: 名前 / 種別 / 説明 / 関連ドメイン / マスク値 / 更新日時 / スコープ（project or user）の表。

### 7. 削除（delete）

入力: 認証情報名。
出力: 削除完了通知（フル値は表示しない）。

対話モードでは削除前にユーザ確認を必須とする（`AskUserQuestion`）。

### 8. プロアクティブ検出

入力: 会話中の文字列パターン（`sk-` `ghp_` `xoxb-` `xoxp-` `Bearer ` `eyJhbG` 等）。
動作: 「これを将来のセッション用に保存しますか?」と提案。承諾されたら step 3 へ。

### 9. 検証

[`../../references/completion-checklist.md`](../../references/completion-checklist.md) に基づき、フル値非露出・パス解決・`.gitignore` 登録・`auth_method` 既定値の各項目を自己検証する。

## 重要な制約

- 認証情報のフル値を会話出力・ログ・コミットメッセージに出してはならない（常にマスクする）
- `credentials.json` をリポジトリにコミットしてはならない（`.gitignore` 登録を確認）
- グローバルルール `~/.claude/rules/security/credentials-management.md` の有無に関わらず、URL/API アクセス時には本スキルを起動して保存済み認証情報を必ず照合すること
- 本プラグイン同梱の `SessionStart` / `UserPromptSubmit` / `PreToolUse` フックから `additionalContext` で本スキルの最優先起動が指示された場合、他のスキル・ツール呼び出しに先立って必ず本スキルを起動すること
- 平文保存のため本番秘匿情報の運用には適さない（README に明示）
- パスポータビリティ準拠（[`../../references/path-portability.md`](../../references/path-portability.md)、自スキル参照は `${CLAUDE_SKILL_DIR}` を使う）
- 既存ファイル更新時のエンコーディング維持（不在時は UTF-8 / 元の改行コードを既定維持）
- 利用者環境非依存性の維持（[`../../references/self-containment.md`](../../references/self-containment.md)、ADR-022）
- ユーザに選択を求める場合は `AskUserQuestion`（[`../../references/user-interaction.md`](../../references/user-interaction.md)）

## 参照

| 用途 | ファイル |
|-----|---------|
| ストアファイル形式・操作詳細 | [`references/operations.md`](references/operations.md) |
| URL 自動マッチ仕様 | [`references/auto-match.md`](references/auto-match.md) |
| セキュリティ注意 | [`references/security.md`](references/security.md) |
