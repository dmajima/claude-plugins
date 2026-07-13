---
name: google-workspace
description: Google Drive のファイル検索・読取・作成・コピー・メタデータ取得・権限確認を MCP 経由で行うスキル。「Drive で議事録を検索して」「Google ドキュメントを作成して」「スプレッドシートを読んで」等で起動。Use when searching, reading, or creating Google Drive files. SKIP when target is another service (use backlog / azure / projectboard / ailead / slack).
---

# Google Workspace Connector

Google Drive のファイル操作を行うコネクタスキル。
MCP ツール経由で認証済みの Google Workspace 接続を利用する。

## 責務

| 責務 | 説明 |
|------|------|
| ファイル検索 | タイトル・全文・MIME種別・日付・所有者でファイルを検索 |
| ファイル読取 | ドキュメント・スプレッドシート・スライド・PDF・画像等の内容を自然言語で読取 |
| ファイルダウンロード | ファイル内容を base64 エンコード文字列として取得（エクスポート形式指定可） |
| メタデータ取得 | ファイル名・種別・更新日時・サイズ等のメタデータを取得 |
| 権限確認 | ファイルの共有権限（閲覧者・編集者等）を確認 |
| 最近のファイル一覧 | 最近アクセス・更新したファイルを一覧表示 |
| ファイル作成 | 新規ドキュメント・スプレッドシート・スライド・フォルダの作成、テキストファイルのアップロード |
| ファイルコピー | 既存ファイルのコピーを作成（タイトル・保存先変更可） |

## 責務外

| 操作 | 担当スキル |
|------|-----------|
| Backlog / Azure DevOps / ProjectBoard | 各専用コネクタスキル |
| Slack 操作 | `connector:slack` |
| ailead 共有リンク取得 | `connector:ailead` |

## トリガー条件

以下のいずれかに該当する場合に本スキルを起動する。

- 「Google Drive で〇〇を検索して」「ドライブのファイルを見せて」等の依頼
- 「Google ドキュメントを作成して」「スプレッドシートを読んで」等の依頼
- 「最近の Google Drive ファイルを見せて」等の依頼
- Google Workspace のファイルに関する情報取得・操作依頼

## 前提

- MCP ツール `mcp__claude_ai_Google_Drive__*` が利用可能であること
- claude.ai 経由の Google Drive 認証が完了していること（MCP が自動管理）
- 別途の API キーや OAuth トークンは不要（MCP 利用時）

## 実行モード判定

| 入力 | モード | 動作 |
|------|-------|------|
| 操作種別と対象が明確 | 非対話 | 対応する MCP ツールを直接呼び出す |
| 操作種別が不明 | 対話 | `AskUserQuestion` で操作を確認 |

## 操作一覧

### 読み取り操作（承認不要）

| 操作 | MCP ツール | 主要パラメータ |
|------|-----------|---------------|
| ファイル検索 | `search_files` | `query`（構造化クエリ構文） |
| ファイル読取 | `read_file_content` | `fileId` |
| ファイルダウンロード | `download_file_content` | `fileId`, `exportMimeType` |
| メタデータ取得 | `get_file_metadata` | `fileId` |
| 権限確認 | `get_file_permissions` | `fileId` |
| 最近のファイル | `list_recent_files` | `orderBy`, `pageSize` |

### 書き込み操作（承認必須）

| 操作 | MCP ツール | 主要パラメータ |
|------|-----------|---------------|
| ファイル作成 | `create_file` | `title`, `textContent`/`base64Content`, `contentMimeType` |
| ファイルコピー | `copy_file` | `fileId`, `title`, `parentId` |

## 実行フロー

### 読み取り操作

1. ユーザーの依頼から操作種別と対象を判定する
2. ファイル名で指定された場合は `search_files` で fileId を解決する
3. 対応する MCP ツールを呼び出す
4. 結果を整形してユーザーに報告する

### 書き込み操作

1. ユーザーの依頼から操作種別・対象・内容を判定する
2. **`AskUserQuestion` で作成内容を提示し、ユーザーの承認を得る**
3. 承認後、対応する MCP ツールを呼び出す
4. 結果（ファイルリンク等）をユーザーに報告する

## 書き込み承認

### 対話モード（ユーザー直接操作）

```
AskUserQuestion({
  question: "以下の内容で Google Drive にファイルを作成してよいですか？",
  header: "Drive 作成",
  options: [
    { label: "作成する", description: "ファイル名: {タイトル}\n種別: {MIME}\n内容: {要約}" },
    { label: "中止", description: "作成を取りやめます" }
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
- `read_file_content` は非常に大きなファイルでは内容が不完全になる場合がある
- `download_file_content` で Google ネイティブファイルをダウンロードする場合は `exportMimeType` が必須
- テキスト/CSV のアップロードはデフォルトで Google ドキュメント/スプレッドシートに変換される（`disableConversionToGoogleType: true` で回避可能）
- MCP 利用時は認証は MCP が自動管理。直接対応（フォールバック）時は [../../references/credentials-precheck.md](../../references/credentials-precheck.md) セクション 1 の解決順序で Bearer トークンを取得する（credentials-manager は **オプション**。未導入時は credentials.json 直接照合 → 対話取得フォールバックでトークンの提供を受ける）
- サブエージェント実行時（`AskUserQuestion` 利用不可）に MCP 利用不可・トークン未解決となった場合は、質問せず `mcp_unavailable` / `credentials_missing` マニフェストを返す（返却動作は [../../references/credentials-precheck.md](../../references/credentials-precheck.md) セクション 5、呼び出し元の復帰は [../../references/subagent-protocol.md](../../references/subagent-protocol.md) セクション 3.5）
- render-check ゲートは Google Drive 操作では不要

## サブエージェント呼び出し（他プラグイン向け）

他プラグインが read 操作を **後続フローのある文脈で** 呼び出す場合は、`Skill()` ではなく `Agent()` を使用すること。`Skill()` では本スキルの結果報告後に呼び出し元のフローが停止する。

詳細なプロトコル・テンプレート・パラメータは [../../references/subagent-protocol.md](../../references/subagent-protocol.md) セクション 5.6 を参照。

| 操作 | 出力ファイル |
|------|-------------|
| ファイル内容取得 | `file-content.json` |
| ファイル検索 | `search-results.json` |

## 参照

| 用途 | ファイル |
|------|---------|
| MCP ツール詳細 | [`references/mcp-tools.md`](references/mcp-tools.md) |
| MCP フォールバック | [`references/mcp-fallback.md`](references/mcp-fallback.md) |
| API 安全原則 | [`../../references/safe-api-access.md`](../../references/safe-api-access.md) |
| サブエージェント呼び出しプロトコル（SSOT） | [`../../references/subagent-protocol.md`](../../references/subagent-protocol.md) |
| 動作分岐検証 | [`evals/`](evals/) |
