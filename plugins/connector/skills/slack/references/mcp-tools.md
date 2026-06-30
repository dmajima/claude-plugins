# Slack MCP ツール詳細

本スキルが利用する MCP ツール（`mcp__claude_ai_Slack__*`）の詳細仕様。

## 読み取りツール

### slack_search_channels

チャンネルを名前・説明で検索する。

| パラメータ | 型 | 必須 | 説明 |
|-----------|---|------|------|
| `query` | string | Yes | 検索クエリ |
| `channel_types` | string | No | `public_channel`, `private_channel` のカンマ区切り |
| `include_archived` | boolean | No | アーカイブ済みを含むか |
| `limit` | integer | No | 最大20件（デフォルト20） |
| `cursor` | string | No | ページネーション |

### slack_search_public

パブリックチャンネルのメッセージ・ファイルを検索する。

| パラメータ | 型 | 必須 | 説明 |
|-----------|---|------|------|
| `query` | string | Yes | 検索クエリ（修飾子対応） |
| `sort` | string | No | `score`（関連度）/ `timestamp`（時系列） |
| `sort_dir` | string | No | `asc` / `desc` |
| `limit` | integer | No | 最大20件 |
| `content_types` | string | No | `messages`, `files` |
| `include_context` | boolean | No | 前後メッセージを含むか |

**検索修飾子**:
- `in:#channel` / `in:<#C123>` — チャンネルフィルタ
- `from:@user` / `from:<@U123>` — 送信者フィルタ
- `before:YYYY-MM-DD` / `after:YYYY-MM-DD` — 日付フィルタ
- `is:thread` / `has:pin` / `has:link` / `has:file` — コンテンツフィルタ
- `"exact phrase"` — 完全一致

### slack_search_public_and_private

全チャンネル（パブリック・プライベート・DM・グループDM）を検索する。
**ユーザーの明示的同意が必要。**

パラメータは `slack_search_public` と同一 + `channel_types` フィルタ。

### slack_read_channel

指定チャンネルのメッセージ履歴を取得する（新しい順）。

| パラメータ | 型 | 必須 | 説明 |
|-----------|---|------|------|
| `channel_id` | string | Yes | チャンネル ID（DM の場合は user_id） |
| `limit` | integer | No | 1〜100（デフォルト100） |
| `oldest` | string | No | 範囲開始タイムスタンプ |
| `latest` | string | No | 範囲終了タイムスタンプ |
| `cursor` | string | No | ページネーション |

### slack_read_thread

特定メッセージのスレッド（親メッセージ + 全返信）を取得する。

| パラメータ | 型 | 必須 | 説明 |
|-----------|---|------|------|
| `channel_id` | string | Yes | チャンネル ID |
| `message_ts` | string | Yes | 親メッセージのタイムスタンプ |
| `limit` | integer | No | 1〜1000（デフォルト100） |

### slack_search_users

名前・メール・属性でユーザーを検索する。

| パラメータ | 型 | 必須 | 説明 |
|-----------|---|------|------|
| `query` | string | Yes | 検索クエリ（名前/メール/部門等） |
| `limit` | integer | No | 最大20件 |

### slack_read_user_profile

ユーザーの詳細プロフィールを取得する。

| パラメータ | 型 | 必須 | 説明 |
|-----------|---|------|------|
| `user_id` | string | No | ユーザーID（省略時: 自分） |

### slack_read_canvas

Canvas ドキュメントの内容と section_id マッピングを取得する。

| パラメータ | 型 | 必須 | 説明 |
|-----------|---|------|------|
| `canvas_id` | string | Yes | Canvas ID |

## 書き込みツール（承認必須）

### slack_send_message

メッセージを送信する。

| パラメータ | 型 | 必須 | 説明 |
|-----------|---|------|------|
| `channel_id` | string | Yes | 送信先チャンネル/ユーザー ID |
| `message` | string | Yes | メッセージ内容（Markdown） |
| `thread_ts` | string | No | スレッド返信時の親メッセージ ts |
| `reply_broadcast` | boolean | No | スレッド返信をチャンネルにも表示 |

**制約**: 5000文字以内。Slack Connect チャンネルには送信不可。

### slack_send_message_draft

下書きを作成する（即時送信はしない）。

| パラメータ | 型 | 必須 | 説明 |
|-----------|---|------|------|
| `channel_id` | string | Yes | チャンネル ID |
| `message` | string | Yes | 下書き内容 |
| `thread_ts` | string | No | スレッド返信時の親メッセージ ts |

### slack_schedule_message

指定日時にメッセージ送信を予約する。

| パラメータ | 型 | 必須 | 説明 |
|-----------|---|------|------|
| `channel_id` | string | Yes | 送信先チャンネル ID |
| `message` | string | Yes | メッセージ内容 |
| `post_at` | integer | Yes | 送信日時（Unix タイムスタンプ、2分以上先、最大120日先） |
| `thread_ts` | string | No | スレッド返信時の親メッセージ ts |

### slack_add_reaction

メッセージに絵文字リアクションを追加する。

| パラメータ | 型 | 必須 | 説明 |
|-----------|---|------|------|
| `channel_id` | string | Yes | チャンネル ID |
| `message_ts` | string | Yes | 対象メッセージのタイムスタンプ |
| `emoji` | string | Yes | 絵文字名（コロンなし: `thumbsup`, `eyes` 等） |

### slack_create_canvas

Canvas ドキュメントを新規作成する。

| パラメータ | 型 | 必須 | 説明 |
|-----------|---|------|------|
| `title` | string | Yes | Canvas タイトル |
| `content` | string | Yes | Canvas 内容（Canvas-flavored Markdown） |

### slack_update_canvas

既存の Canvas を更新する。

| パラメータ | 型 | 必須 | 説明 |
|-----------|---|------|------|
| `canvas_id` | string | Yes | Canvas ID |
| `action` | string | Yes | `append` / `prepend` / `replace` |
| `content` | string | Yes | 更新内容（Canvas-flavored Markdown） |
| `section_id` | string | No | 更新対象セクション ID |

**注意**: `action=replace` + `section_id` なし = **全文上書き**。必ず事前に `slack_read_canvas` で section_id を取得する。
