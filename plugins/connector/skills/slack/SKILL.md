---
name: slack
description: Slack のチャンネル・メッセージ・ユーザー・Canvas を MCP 経由で操作するスキル。「Slack の #general を読んで」「Slack でメッセージを送って」「Canvas を作成して」等で起動。Use when searching, reading, or sending Slack messages or managing Canvases. SKIP when target is another service (use backlog / azure / projectboard / ailead / google-workspace).
---

# Slack Connector

Slack ワークスペースの情報取得・メッセージ送信・Canvas操作を行うコネクタスキル。
MCP ツール経由で認証済みの Slack 接続を利用する。

## 責務

| 責務 | 説明 |
|------|------|
| チャンネル検索 | 名前・説明でチャンネルを検索 |
| メッセージ検索 | キーワード・フィルタでメッセージを検索（公開/全チャンネル） |
| チャンネル読取 | 指定チャンネルのメッセージ履歴を取得 |
| スレッド読取 | 特定メッセージのスレッド（返信）を取得 |
| ユーザー検索 | 名前・メール・属性でユーザーを検索 |
| ユーザー情報取得 | ユーザーの詳細プロフィールを取得 |
| メッセージ送信 | チャンネル・DMへメッセージを送信 |
| メッセージ下書き | 下書きを作成（送信はしない） |
| メッセージ予約 | 指定日時にメッセージ送信を予約 |
| リアクション追加 | メッセージに絵文字リアクションを追加 |
| Canvas操作 | Canvas の作成・読取・更新 |

## 責務外

| 操作 | 担当スキル |
|------|-----------|
| Backlog 課題操作 | `connector:backlog` |
| Azure DevOps PR/作業項目操作 | `connector:azure` |
| ProjectBoard WBS操作 | `connector:projectboard` |
| ailead 共有リンク取得 | `connector:ailead` |
| 投稿前レンダリングチェック | `connector:render-check`（Slack 送信では不要） |

## トリガー条件

以下のいずれかに該当する場合に本スキルを起動する。

- 「Slack で〇〇を検索して」「Slack の #general を見て」等の依頼
- 「Slack でメッセージを送って」「Slack に投稿して」等の依頼
- 「Slack の Canvas を作成して」等の依頼
- Slack のチャンネル・メッセージ・ユーザーに関する情報取得依頼

## 前提

- MCP ツール `mcp__claude_ai_Slack__*` が利用可能であること
- claude.ai 経由の Slack 認証が完了していること（MCP が自動管理）
- 別途の API キーや Bearer Token は不要

## 実行モード判定

| 入力 | モード | 動作 |
|------|-------|------|
| 操作種別と対象が明確 | 非対話 | 対応する MCP ツールを直接呼び出す |
| 操作種別が不明 | 対話 | `AskUserQuestion` で操作を確認 |

## 操作一覧

### 読み取り操作（承認不要）

| 操作 | MCP ツール | 主要パラメータ |
|------|-----------|---------------|
| チャンネル検索 | `slack_search_channels` | `query` |
| メッセージ検索（公開） | `slack_search_public` | `query`, `sort`, `limit` |
| メッセージ検索（全チャンネル） | `slack_search_public_and_private` | `query`, `sort`, `limit` |
| チャンネル読取 | `slack_read_channel` | `channel_id`, `limit`, `oldest`, `latest` |
| スレッド読取 | `slack_read_thread` | `channel_id`, `message_ts` |
| ユーザー検索 | `slack_search_users` | `query` |
| ユーザー情報取得 | `slack_read_user_profile` | `user_id` |
| Canvas 読取 | `slack_read_canvas` | `canvas_id` |

### 書き込み操作（承認必須）

| 操作 | MCP ツール | 主要パラメータ |
|------|-----------|---------------|
| メッセージ送信 | `slack_send_message` | `channel_id`, `message` |
| メッセージ下書き | `slack_send_message_draft` | `channel_id`, `message` |
| メッセージ予約 | `slack_schedule_message` | `channel_id`, `message`, `post_at` |
| リアクション追加 | `slack_add_reaction` | `channel_id`, `message_ts`, `emoji` |
| Canvas 作成 | `slack_create_canvas` | `title`, `content` |
| Canvas 更新 | `slack_update_canvas` | `canvas_id`, `action`, `content` |

## 実行フロー

### 読み取り操作

1. ユーザーの依頼から操作種別と対象を判定する
2. 対象が名前で指定された場合は前段の検索を行う（例: チャンネル名 → channel_id の解決）
3. 対応する MCP ツールを呼び出す
4. 結果を整形してユーザーに報告する

### 書き込み操作

1. ユーザーの依頼から操作種別・対象・内容を判定する
2. 対象が名前で指定された場合は前段の検索を行う（チャンネル名/ユーザー名 → ID 解決）
3. **`AskUserQuestion` で送信内容・送信先を提示し、ユーザーの承認を得る**
4. 承認後、対応する MCP ツールを呼び出す
5. 結果（メッセージリンク等）をユーザーに報告する

## チャンネル/ユーザー ID 解決

Slack MCP ツールの多くは `channel_id` や `user_id` を要求する。
ユーザーがチャンネル名やユーザー名で指定した場合は、以下の順で ID を解決する。

1. **チャンネル名 → channel_id**: `slack_search_channels` で検索
2. **ユーザー名 → user_id**: `slack_search_users` で検索
3. **複数候補**: `AskUserQuestion` でユーザーに選択を求める
4. **該当なし**: ユーザーにチャンネル/ユーザーが見つからない旨を報告

## 書き込み承認

### 対話モード（ユーザー直接操作）

```
AskUserQuestion({
  question: "以下の内容で Slack に送信してよいですか？",
  header: "Slack 送信",
  options: [
    { label: "送信する", description: "送信先: #general\n内容: {メッセージ要約}" },
    { label: "中止", description: "送信を取りやめます" }
  ]
})
```

### 非対話モード（別スキルからの呼び出し等）

非対話モード（呼び出し元が引数に `--non-interactive` を含む、または別スキルから `Skill()` 経由で操作種別・対象・内容がすべて確定済みの状態で呼び出された場合）では `AskUserQuestion` を省略し、エージェントの判断で書き込みを実行してよい。

## MCP 未導入時のフォールバック

MCP ツール利用不可の場合は MCP 導入サポート or 直接 API の選択肢を提示する。
詳細は [`references/mcp-fallback.md`](references/mcp-fallback.md) を参照。

## 重要な制約

- **対話モードでは書き込み操作で `AskUserQuestion` による承認を得てから実行する**（非対話モードではエージェント判断で省略可）
- **プライベートチャンネル・DM の検索はユーザーの明示的同意を得てから実行する**
- メッセージは 5000 文字以内（Slack の制限）
- Canvas 更新で `action=replace` + `section_id` なしは全文上書きになるため、事前に `slack_read_canvas` で section_id を取得する
- render-check ゲートは Slack 送信では不要（Slack は独自の Markdown 記法を使用し、MCP ツールが処理する）
- MCP 利用時は認証情報の管理は MCP が自動的に行うため、credentials-manager は使用しない
- 直接対応（フォールバック）時は [../../references/credentials-precheck.md](../../references/credentials-precheck.md) セクション 1 の解決順序で API トークンを取得する（credentials-manager は **オプション**。未導入時は credentials.json 直接照合 → 対話取得フォールバックでトークンの提供を受ける）
- サブエージェント実行時（`AskUserQuestion` 利用不可）に MCP 利用不可・トークン未解決となった場合は、質問せず `mcp_unavailable` / `credentials_missing` マニフェストを返す（返却動作は [../../references/credentials-precheck.md](../../references/credentials-precheck.md) セクション 5、呼び出し元の復帰は [../../references/subagent-protocol.md](../../references/subagent-protocol.md) セクション 3.5）

## サブエージェント呼び出し（他プラグイン向け）

他プラグインが read 操作を **後続フローのある文脈で** 呼び出す場合は、`Skill()` ではなく `Agent()` を使用すること。`Skill()` では本スキルの結果報告後に呼び出し元のフローが停止する。

詳細なプロトコル・テンプレート・パラメータは [../../references/subagent-protocol.md](../../references/subagent-protocol.md) セクション 5.5 を参照。

| 操作 | 出力ファイル |
|------|-------------|
| チャンネル読取 | `messages.json` |
| メッセージ検索 | `search-results.json` |
| スレッド読取 | `thread.json` |
| ユーザー情報 | `user-profile.json` |

## 参照

| 用途 | ファイル |
|------|---------|
| MCP ツール詳細 | [`references/mcp-tools.md`](references/mcp-tools.md) |
| MCP フォールバック | [`references/mcp-fallback.md`](references/mcp-fallback.md) |
| API 安全原則 | [`../../references/safe-api-access.md`](../../references/safe-api-access.md) |
| サブエージェント呼び出しプロトコル（SSOT） | [`../../references/subagent-protocol.md`](../../references/subagent-protocol.md) |
| 動作分岐検証 | [`evals/`](evals/) |
