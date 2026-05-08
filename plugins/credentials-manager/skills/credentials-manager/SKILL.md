---
name: credentials-manager
description: Claude Code セッションの認証情報ストア（APIキー・トークン・パスワード・秘密鍵）を追加・編集・削除する管理特化スキル。`credentials.json` への書き込み操作と保存先スコープ（リポジトリ単位 / ユーザー単位）の自動解決、`.gitignore` 登録確認、JSON 破損時のバックアップ＋再初期化を担当する。「APIキーを保存して」「保存済みの GitHub トークンを更新」「openai-api-key を削除」「/credentials-manager:manage」「保存済み認証情報を編集」等で起動する。Use when adding, editing, deleting, or repairing stored credentials, or invoking the manage command. SKIP when only retrieving, listing for reference, auto-matching by URL/domain, or detecting credential patterns (use credentials-reader).
---

# Credentials Manager

Claude Code セッションの認証情報ストア（`credentials.json`）に対する **書き込み（追加・編集・削除）** に特化した管理スキル。参照・自動マッチ・プロアクティブ検出は `credentials-reader` に委譲する。

## 責務

- 認証情報の **追加（save）**・**編集（update）**・**削除（delete）**
- 保存先スコープ（リポジトリ単位 or ユーザー単位）の自動解決と親ディレクトリ作成
- `.gitignore` 登録確認・警告
- `credentials.json` 破損時の **バックアップ + 再初期化（repair）**
- `/credentials-manager:manage` コマンドからの呼び出し受け入れ

## 責務外（他スキル・コマンドが担当）

| 業務 | 担当 |
|-----|-----|
| 認証情報の取得（retrieve） / 一覧（list、参照目的） | [`credentials-reader`](../credentials-reader/SKILL.md) |
| URL/ドメイン関連付けによる自動マッチ・自動適用 | [`credentials-reader`](../credentials-reader/SKILL.md) |
| 認証情報パターンのプロアクティブ検出 | [`credentials-reader`](../credentials-reader/SKILL.md) |
| メニューUIによる対話的な管理操作の進行 | [`/credentials-manager:manage`](../../commands/manage.md) コマンド |
| 秘密鍵生成・暗号化・KMS連携・本番秘匿情報運用 | スキル外（外部 secret manager） |
| マーケットプレイス公開時のシークレットスキャン | `marketplace-publisher`（`extension-toolkit`） |

## トリガー条件

明示要求トリガー:

- 「OpenAI の API キー `sk-...` を保存して」
- 「GitHub のトークンを覚えておいて」
- 「openai-api-key を削除して」
- 「保存済みの xxx を更新して」
- `/credentials-manager:manage` コマンドからの呼び出し

引き継ぎトリガー（`credentials-reader` から）:

- 0 件マッチ後の保存承諾
- プロアクティブ検出後の保存承諾
- JSON パース失敗時の修復（repair）

このスキルを起動しないケース:

- 単なる参照・一覧表示・自動マッチ → `credentials-reader` を使う
- 認証情報の検出のみ（保存しない選択） → `credentials-reader` で完結

## 前提

呼び出し前に以下を解決する:

1. 現在のワーキングディレクトリ（リポジトリ内 or 外）の判定
2. 認証情報ファイルパスの解決（次節「実行フロー」step 1）
3. リポジトリ内の場合は `.claude/.local/` が `.gitignore` に登録されているか

未確定の場合は実行フロー内で順次解決する。

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| 引数で対象認証情報名・値・URL が全指定 / `--non-interactive` 相当 | 非対話 | 確認をスキップしデフォルト値で確定し進行 |
| 上記以外（多くは自然言語入力） | 対話 | 不足パラメータを `AskUserQuestion` でユーザに確認 |

## 実行フロー

### 1. 認証情報ファイルパスを解決

| 優先順位 | 条件 | パス |
|---------|------|------|
| 1（優先） | 現在のディレクトリ（または祖先ディレクトリ）に `.git` がある | `<repo_root>/.claude/.local/plugins/credentials-manager/credentials.json` |
| 2（フォールバック） | リポジトリ外での作業 | `~/.claude/.local/plugins/credentials-manager/credentials.json` |

- 親ディレクトリ（`.claude/.local/plugins/credentials-manager/`）が無ければ作成する
- ファイル不在時は空ストア `{"credentials": {}}` として扱い、初回書き込み時に作成する
- 解決パスは操作のたびに再評価する
- 解決パスがリポジトリ内の場合、`.claude/.local/` が `.gitignore` に未登録ならユーザに警告してから書き込みを行う

### 2. 操作種別を判定

| ユーザ意図 | 動作分岐 |
|-----------|---------|
| 保存（save、新規） | step 3 |
| 編集（update、既存値の更新） | step 4 |
| 削除（delete） | step 5 |
| 修復（repair、JSON 破損時のバックアップ + 再初期化） | step 6 |

### 3. 保存（save）

入力: 認証情報の値、識別名（不足時はユーザに確認）、種別、関連 URL/ドメイン（任意）。
出力: マスク済み値 + 保存先パス + 関連 URL/ドメイン + スコープ。
詳細: [`references/operations.md`](references/operations.md) 節 2

### 4. 編集（update）

入力: 認証情報名（部分一致可）、変更フィールド（`value` / `urls` / `domains` / `auth_method` / `description` / `type`）。
出力: 変更前 / 変更後の比較表（マスク済み）+ `updated_at` 更新。
詳細: [`references/operations.md`](references/operations.md) 節 3

### 5. 削除（delete）

入力: 認証情報名。
出力: 削除完了通知（フル値は表示しない）。
詳細: [`references/operations.md`](references/operations.md) 節 4

対話モードでは削除前にユーザ確認を必須とする（`AskUserQuestion`）。

### 6. 修復（repair）

入力: なし（JSON パース失敗の検出を契機に起動）。
出力: バックアップファイルパス + 空ストアでの再初期化通知。
詳細: [`references/operations.md`](references/operations.md) 節 5

### 7. 検証

[`../../references/completion-checklist.md`](../../references/completion-checklist.md) に基づき、フル値非露出・パス解決・`.gitignore` 登録・`auth_method` 既定値の各項目を自己検証する。

## 重要な制約

- 認証情報のフル値を会話出力・ログ・コミットメッセージに出してはならない（常にマスクする）
- `credentials.json` をリポジトリにコミットしてはならない（`.gitignore` 登録を確認）
- 参照系操作（retrieve / list / auto-match / proactive-detect）は本スキルでは行わず、`credentials-reader` を案内する
- 本プラグイン同梱の `SessionStart` フックでルールテンプレートが配置される。`PreToolUse` / `UserPromptSubmit` フックの `additionalContext` は **`credentials-reader` の最優先起動** を指示する設計であり、本スキルは引き継ぎ・明示要求・コマンド経由でのみ起動する
- 平文保存のため本番秘匿情報の運用には適さない（README に明示）
- パスポータビリティ準拠（自スキル参照は `${CLAUDE_SKILL_DIR}` を使う）
- 既存ファイル更新時のエンコーディング維持（不在時は UTF-8 / 元の改行コードを既定維持）
- ユーザに選択を求める場合は `AskUserQuestion`

## 参照

| 用途 | ファイル |
|-----|---------|
| ストアファイル形式・操作詳細（save / update / delete / repair） | [`references/operations.md`](references/operations.md) |
| セキュリティ注意 | [`references/security.md`](references/security.md) |
| reader 引き継ぎ受け入れ仕様（呼び出し元の責務記述、参照のみ） | [`references/operations.md` 節 9](references/operations.md) |
| 自己検証チェックリスト | [`../../references/completion-checklist.md`](../../references/completion-checklist.md) |
