---
name: credentials-reader
description: Claude Code セッションをまたいで保存済み認証情報（APIキー・トークン・パスワード・秘密鍵）を URL/ドメイン関連付けで自動マッチ・自動適用し、フル値の取得・一覧表示を担う参照専用スキル。認証情報パターン（sk-/ghp_/xoxb-/AKIA/AIza 等）、外部通信コマンド（curl/wget/gh/ssh/WebFetch/Invoke-RestMethod/IaC CLI）、認証情報系ファイル（.env/credentials.json/secrets.*/id_rsa/~/.aws/credentials/~/.kube/config/*.pem/*.key 等）の操作を検知。「保存済み認証情報を一覧」「先ほどのキーで API を叩いて」「.env を読んで」「id_rsa を生成」等で起動する。Use when retrieving stored credentials, auto-matching by URL/domain, listing for reference, accessing any URL/API endpoint, invoking IaC/secret CLIs, or reading credential-bearing files. SKIP only for pure write-only requests (use credentials-manager); for any retrieval/access, run reader first.
---

# Credentials Reader

保存済み認証情報を **読み出す側の責務** に特化した軽量スキル。Claude Code のフック（PreToolUse / UserPromptSubmit）から最優先で呼ばれることを想定し、必要最小限のコンテキストで照合・自動適用・引き継ぎ判断を行う。

> **description 文字数の例外**: 本スキルは認証情報・外部通信検出のため、認証情報パターン・対象ファイル・対象コマンドの網羅的列挙が AI 自動トリガー精度の確保に必要不可欠であり、誤起動・トリガー漏れが直接的にセキュリティ事故につながる。`extension-toolkit/references/description-guide.md` 節 3.3.1 の例外規定（セキュリティクリティカル、上限 700 字）に基づき、通常 300 字上限を超過する設計を採用している。

## 責務

- 保存済み認証情報の **取得（retrieve）**・**一覧（list）**
- URL/ドメイン関連付けによる **自動マッチ・自動適用**（auto-match）
- 認証情報パターン（`sk-` `ghp_` `xoxb-` `AKIA` `AIza` `Bearer` `eyJ` `PEM` 等）の **プロアクティブ検出**
- 検出時に追加・編集・削除が必要な場合は `credentials-manager` への **引き継ぎ判断**
- 認証情報値のマスキング表示（先頭4文字 + `****` + 末尾4文字）

## 責務外（他スキルが担当）

| 業務 | 担当 |
|-----|-----|
| 認証情報の追加・編集・削除（書き込み操作） | `credentials-manager` |
| 認証情報ストアの初期化・スキーマ移行 | `credentials-manager` |
| `/credentials-manager:manage` コマンド本体（メニューUI） | `commands/manage.md` |
| 秘密鍵生成・暗号化・KMS連携・本番秘匿情報運用 | スキル外（外部 secret manager） |
| マーケットプレイス公開時のシークレットスキャン | `marketplace-publisher`（`extension-toolkit`） |

## トリガー条件

明示要求（参照系）:

- 「保存してある認証情報を一覧表示して」
- 「前に保存した API キーで API を叩いて」
- 「OpenAI のキーが保存されているか確認して」

暗黙トリガー（**フック起動経由を含め必須起動**）:

- ユーザが URL / API エンドポイントへのアクセス（WebFetch・curl・wget・`gh api`・Python requests・Node fetch・任意スクリプト等）を依頼した場合
- 会話中にユーザが認証情報らしい文字列（`sk-` `ghp_` `xoxb-` `xoxp-` `Bearer ` 等）を貼り付けた場合
- 認証情報系ファイル（`.env` / `credentials.json` / `id_rsa` / `*.pem` / `*.key` / `~/.aws/credentials` / `~/.kube/config` 等）を読み書きする場合

このスキルを起動しないケース:

- ユーザが明示的に「保存して」「削除して」「編集して」と書き込み操作を要求している → `credentials-manager` を起動
- 認証情報・URL アクセス・外部サービス通信に一切関係しない依頼

## 前提

呼び出し前に以下を解決する:

1. 現在のワーキングディレクトリ（リポジトリ内 or 外）の判定
2. 認証情報ファイルパスの解決（次節「実行フロー」step 1）

未確定の場合は実行フロー内で順次解決する。書き込みは行わないため `.gitignore` 登録チェックは引き継ぎ先（`credentials-manager`）の責務とする。

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| 引数で対象認証情報名・URL が全指定 / `--non-interactive` 相当 | 非対話 | 確認をスキップしデフォルト値で進行（マッチ複数件時は最新更新を採用） |
| 上記以外（多くは自然言語入力） | 対話 | 不足パラメータを `AskUserQuestion` でユーザに確認 |

## 実行フロー

### 1. 認証情報ファイルパスを解決

| 優先順位 | 条件 | パス |
|---------|------|------|
| 1（優先） | 現在のディレクトリ（または祖先ディレクトリ）に `.git` がある | `<repo_root>/.claude/.local/plugins/credentials-manager/credentials.json` |
| 2（フォールバック） | リポジトリ外での作業 | `~/.claude/.local/plugins/credentials-manager/credentials.json` |

- 親ディレクトリが無ければ作成しない（参照のみのため、書き込み発生時に `credentials-manager` へ引き継ぐ）
- ファイル不在時は **空ストア相当** として扱い、step 2 で操作種別に応じた応答を行う
- 解決パスは操作のたびに再評価する

### 2. 操作種別を判定

| ユーザ意図 | 動作分岐 |
|-----------|---------|
| 取得（retrieve、認証情報名指定 or 部分一致） | step 3 |
| URL自動マッチ（auto-match、URL/ドメイン指定） | step 4 |
| 一覧（list、参照目的） | step 5 |
| プロアクティブ検出（パターン検出） | step 6 |
| 書き込みが必要（保存・編集・削除） | step 7（引き継ぎ） |

### 3. 取得（retrieve）

入力: 認証情報名（部分一致可）。
出力: フル値（プログラム利用時のみ） / マスク済み値（ユーザ表示時）。
詳細: [`references/retrieve.md`](references/retrieve.md)

### 4. URL 自動マッチ（auto-match、**暗黙トリガー時の中核動作**）

入力: ユーザのリクエスト URL / ドメイン。
出力: マッチ件数に応じた挙動（自動適用 / 選択依頼 / 引き継ぎ）。
詳細: [`references/auto-match.md`](references/auto-match.md)

| マッチ件数 | 動作 |
|----------|------|
| 1件 | `auth_method` に従って自動適用、ユーザに「保存済み認証情報 `<name>` (`****`) を `<domain>` に自動適用しました」と通知 |
| 複数件 | `AskUserQuestion` でどれを使うか確認（マスク済み値表示） |
| 0件 | 「`<domain>` 用の認証情報は保存されていません。保存しますか？」と確認 → 保存承諾なら **step 7 で credentials-manager に引き継ぎ**（マスク値・候補名のみ渡し、フル値はユーザに再入力させる。詳細: [`handoff.md`](references/handoff.md) 節 3） |

### 5. 一覧（list）

入力: なし。
出力: 名前 / 種別 / 説明 / 関連ドメイン / マスク値 / 更新日時 / スコープ（project or user）の表 + 保存先パス。

参照目的の表示のみを担当する。表示後に「追加・編集・削除をしますか？」と尋ねられた場合は step 7 で引き継ぐ。

### 6. プロアクティブ検出

入力: 会話中の文字列パターン（`sk-` `ghp_` `xoxb-` `xoxp-` `AKIA` `AIza` `glpat-` `Bearer ` `eyJ` `PEM` 等）。
動作:

1. 検出文字列を **マスク** して通知（フル値は復唱しない）
2. 文脈から推定した識別名・関連ドメインを提示
3. 「これを将来のセッション用に保存しますか？」とユーザに確認
4. 承諾されたら step 7 で `credentials-manager` に引き継ぎ（マスク値・候補名のみ渡し、フル値はユーザに再入力させる。詳細: [`handoff.md`](references/handoff.md) 節 3）

### 7. 書き込みが必要な場合の引き継ぎ

参照スキルでは追加・編集・削除を行わない。以下のいずれかが必要になった場合は **必ず `Skill` ツール経由で `credentials-manager` を起動** すること（自然言語案内のみで完結させない）。

| 状況 | 起動先 |
|-----|--------|
| 0 件マッチ → 新規保存（save） | `Skill(skill: "credentials-manager:credentials-manager", args: "save ...")` |
| 既存値の更新（update / urls / domains / auth_method の変更） | `Skill(skill: "credentials-manager:credentials-manager", args: "update ...")` |
| エントリ削除（delete） | `Skill(skill: "credentials-manager:credentials-manager", args: "delete ...")` |
| インタラクティブな管理操作 | `/credentials-manager:manage` コマンドを案内 |
| `credentials.json` 破損時の修復 | `Skill(skill: "credentials-manager:credentials-manager", args: "repair")` |

ユーザへの自然言語案内は Skill 起動と **併用** する補助通知であり、Skill 起動を省略してはならない。

引き継ぎ時はマスク済み情報のみを次スキルに渡し、フル値はメインコンテキストにも引き継ぎログにも残さない。フル値が必要な場合は `credentials-manager` 側で `AskUserQuestion` でユーザに再入力を求める（詳細: [`handoff.md`](references/handoff.md) 節 3）。

### 8. 検証

[`../../references/completion-checklist.md`](../../references/completion-checklist.md) に基づき、フル値非露出・パス解決・マスキング規則・引き継ぎ判断の各項目を自己検証する。

## 重要な制約

- 認証情報のフル値を会話出力・ログ・コミットメッセージに出してはならない（常にマスクする）
- 本スキルは **書き込みを行わない**。`credentials.json` の生成・更新・削除は `credentials-manager` に委譲する
- 本プラグイン同梱の `SessionStart` / `UserPromptSubmit` / `PreToolUse` フックから `additionalContext` で本スキルの最優先起動が指示された場合、他のスキル・ツール呼び出しに先立って必ず本スキルを起動すること
- グローバルルール `~/.claude/rules/security/credentials-management.md` の有無に関わらず、URL/API アクセス時には本スキルを起動して保存済み認証情報を必ず照合すること
- パスポータビリティ準拠（自スキル参照は `${CLAUDE_SKILL_DIR}` を使う）
- ユーザに選択を求める場合は `AskUserQuestion` を用いる

## 参照

| 用途 | ファイル |
|-----|---------|
| 取得（retrieve）詳細 | [`references/retrieve.md`](references/retrieve.md) |
| URL 自動マッチ仕様 | [`references/auto-match.md`](references/auto-match.md) |
| 引き継ぎ仕様（→ credentials-manager） | [`references/handoff.md`](references/handoff.md) |
| セキュリティ注意 | [`references/security.md`](references/security.md) |
