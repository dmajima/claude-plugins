---
name: backlog
description: Backlog の課題検索・課題/コメント取得・コメント投稿・メタ情報更新（ステータス等）・共有ファイル一覧取得を行うスキル。「Backlog で PROJ-123 を取得」「課題検索」「コメント投稿」「ステータス変更」等で起動。/file/ か /alias/file/ を含む Backlog URL の入力でも起動。Use when operating Backlog issues or shared files. SKIP when target is Azure DevOps (use azure) or rendering-only check (use render-check).
---

# Backlog

Backlog REST API v2 で課題の検索・取得・コメント取得（読み取り）、コメント投稿・ステータス等メタ情報更新（書き込み）、共有ファイルの一覧取得・メタデータ取得（読み取り）を行うスキル。書き込みは `render-check` ゲートとユーザー承認を必ず経由する。

## 責務

- 課題検索・課題取得・コメント取得（読み取り系）
- コメント投稿・課題メタ情報更新（ステータス・担当者・優先度・期限等。書き込み系）
- 共有ファイルの一覧取得・メタデータ取得（読み取り系。ファイルダウンロードは対象外）
- プロジェクトの記法設定（textFormattingRule）の取得と `render-check` への引き継ぎ

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| Azure DevOps（PR / 作業項目）の操作 | `azure` |
| 投稿本文のレンダリング検証ロジック | `render-check` |
| 認証情報の恒久保存・一元管理 | credentials-manager プラグイン（**オプション**。未導入でも本スキルは [credentials-precheck.md](../../references/credentials-precheck.md) セクション 1 の解決順序＝credentials.json 直接照合 → 対話取得フォールバックで動作する） |

## トリガー条件

- 「Backlog で PROJ-123 を取得して」「PROJ-123 の内容とコメントを見せて」
- 「Backlog で『ログイン』に関する課題を検索して」
- 「PROJ-123 にこの調査結果をコメント投稿して」
- 「PROJ-123 のステータスを処理中に変更して」「担当者を山田さんにして」
- 「このファイルリンクの中身を見せて」（URL に `/file/` または `/alias/file/` を含む Backlog URL）
- 「Backlog の共有ファイルを一覧表示して」
- 他プラグイン（investigation 等）から Skill ツール経由で「読み取りのみ」と明示された受領目的の呼び出しを受けた場合（読み取り系のみ実行し、書き込み操作には進まない）

このスキルを起動しないケース:

- Azure DevOps の PR・作業項目の操作（→ `azure`）
- 投稿せずレンダリング確認だけしたい（→ `render-check`）
- Backlog のファイルをダウンロードしたい（本スキルではメタデータ取得のみ。ダウンロードは未サポート）

## 前提

呼び出し前に以下が確認できること（不足時は対話で確認）:

1. 対象スペースのホスト（例: `<space>.backlog.jp`）— 課題 URL・課題キー・ユーザー指定から特定
2. 対象スペースの API キー — 認証情報ストア（credentials.json）のエントリ、または対話取得フォールバックでユーザーから取得（[credentials-precheck.md](../../references/credentials-precheck.md) セクション 1 の解決順序。credentials.json 未整備でも前提未達にはならない）

## 実行モード判定

| 入力 | モード | 動作 |
|------|-------|------|
| ユーザー直接の指示 / スラッシュコマンド | 対話 | 不足情報の確認・書き込み承認・対話取得フォールバックを `AskUserQuestion` で行う |
| 他プラグインからの `Skill()` 委譲（「読み取りのみ」等の明示） | 非対話 | 明示された読み取り操作のみ実行する（書き込みの承認は省略しない） |
| サブエージェント起動（`Agent()` 経由） | 非対話 | 質問せず実行し、認証未解決時は `credentials_missing` マニフェストを返す |

## 実行フロー

### 1. 認証事前確認

- 参照: [../../references/credentials-precheck.md](../../references/credentials-precheck.md)
- 対象スペースのホストを確定し、セクション 1 の解決順序（credentials-manager（導入時）→ credentials.json 直接照合 → 対話取得フォールバック）で API キーを解決する
- 確認できない場合も **API は呼ばない**。credentials-manager / credentials.json が無くても停止せず、対話取得フォールバック（同セクション 4）で API キーをユーザーから取得して続行する（ユーザーが中止を選択した場合のみ終了）
- サブエージェント実行時（`AskUserQuestion` 利用不可）は質問せず `credentials_missing` マニフェストを返す（同セクション 5）

### 2. 操作種別判定

| 種別 | 操作 | 後続 |
|-----|------|------|
| 読み取り | 課題検索 / 課題取得 / コメント取得 / ステータス・ユーザー等の一覧取得 | Step 3 |
| 読み取り | 共有ファイル一覧取得 / ファイルメタデータ取得 | Step 3 |
| 書き込み | コメント投稿 / 課題メタ情報更新 | Step 4 |

**ファイル URL の判定**: 入力に以下のパターンを含む URL がある場合、共有ファイル操作と判定する。

- `https://{space-host}/file/{projectKey}/...` — ダイレクトパス URL
- `https://{space-host}/alias/file/{id}` — エイリアス URL

課題 URL（`/view/PROJ-123`）とは `/file/` または `/alias/file/` の有無で区別する。

### 3. 読み取り系の実行

- 参照: [references/api-read.md](references/api-read.md)
- [safe-api-access.md](../../references/safe-api-access.md) の原則（ホワイトリスト・タイムアウト・HTTP エラー分岐）で API を呼び出す
- 結果は要点を整形して報告する（課題キー・件名・ステータス・担当者・本文要約・コメント等）。API キーを含む URL はマスクして扱う

### 4. 書き込み系の実行

1. **記法判定**: `GET /api/v2/projects/{projectIdOrKey}` で `textFormattingRule` を取得（`backlog` / `markdown`）
2. **render-check ゲート（必須）**: 投稿本文 + ターゲット（`backlog-notation` / `backlog-markdown`）で `render-check` スキルを実行。FAIL が解消されるまで投稿しない
3. **メタ情報の ID 解決**: ステータス名・担当者名・優先度名は一覧 API で ID に解決する（[references/api-read.md](references/api-read.md)）。曖昧な場合は候補を提示して確認
4. **承認**: 投稿先（課題キー）・操作内容・確定本文（または変更フィールドと変更前後の値）を提示し、`AskUserQuestion` で承認を得る
5. **署名の自動付加**: コメント投稿時、投稿本文の末尾に [../../references/signatures.md](../../references/signatures.md) の署名を自動付加する（既に署名が含まれている場合はスキップ）
6. **実行**: [references/api-write.md](references/api-write.md) の手順で API を呼び出す
7. **結果検証**: レスポンスの ID・更新後の値を確認し、課題 URL とともに報告する

### 5. 引き渡し

- 操作結果（取得内容 / 投稿コメント URL / 更新後ステータス等）を報告する
- 続けて関連操作（コメント追記・ステータス変更等）が必要かを確認する

## 重要な制約

- [safe-api-access.md](../../references/safe-api-access.md) の安全原則（ホワイトリスト・シークレット取り扱い・エラー分岐・書き込みゲート）に必ず従う
- **render-check 未通過・ユーザー未承認での書き込み禁止**（非対話モードでも承認は省略しない）
- 依頼された操作のみ実行する（依頼外の課題への書き込み・一括変更をしない。複数課題の一括更新はユーザーの明示指示 + 対象一覧の承認がある場合のみ）
- API キーのフル値・`apiKey=` 付き URL を会話出力・ログに出さない（マスクする）
- 別スペースの API キーを流用しない（domains 照合で一致するエントリのみ使用）

## サブエージェント呼び出し（他プラグイン向け）

他プラグインが read 操作を **後続フローのある文脈で** 呼び出す場合は、`Skill()` ではなく `Agent()` を使用すること。`Skill()` では本スキルの結果報告後に呼び出し元のフローが停止する。

詳細なプロトコル・テンプレート・パラメータは [../../references/subagent-protocol.md](../../references/subagent-protocol.md) セクション 5.3 を参照。

| 操作 | 出力ファイル |
|------|-------------|
| 課題取得 | `issue.json` |
| 課題検索 | `search-results.json` |
| ファイル一覧取得 | `file-list.json` |

## 参照

| 用途 | ファイル |
|-----|---------|
| 読み取り API 詳細 | [references/api-read.md](references/api-read.md) |
| 書き込み API 詳細 | [references/api-write.md](references/api-write.md) |
| 認証事前確認 | [../../references/credentials-precheck.md](../../references/credentials-precheck.md) |
| API アクセス安全原則 | [../../references/safe-api-access.md](../../references/safe-api-access.md) |
| 投稿署名（SSOT） | [../../references/signatures.md](../../references/signatures.md) |
| 委譲インターフェース仕様（SSOT） | [../../references/delegation-interface.md](../../references/delegation-interface.md) |
| サブエージェント呼び出しプロトコル（SSOT） | [../../references/subagent-protocol.md](../../references/subagent-protocol.md) |
| Backlog 記法ルール | [../../references/rendering/backlog-notation.md](../../references/rendering/backlog-notation.md) |
| Backlog Markdown ルール | [../../references/rendering/backlog-markdown.md](../../references/rendering/backlog-markdown.md) |
| 動作例 | [evals/](evals/) |
