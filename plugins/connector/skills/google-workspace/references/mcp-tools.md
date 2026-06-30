# Google Drive MCP ツール詳細

本スキルが利用する MCP ツール（`mcp__claude_ai_Google_Drive__*`）の詳細仕様。

## 読み取りツール

### search_files

構造化クエリでファイルを検索する。

| パラメータ | 型 | 必須 | 説明 |
|-----------|---|------|------|
| `query` | string | No | 検索クエリ（構造化構文）。省略時は全ファイルが対象になるため `pageSize` による件数制限を推奨 |
| `pageSize` | integer | No | 返却件数上限 |
| `pageToken` | string | No | ページネーション |
| `excludeContentSnippets` | boolean | No | コンテンツスニペットを除外 |

**クエリ構文**: `query_term operator values` を `and` / `or` / `not` で結合。
文字列は単一引用符で囲む。エスケープは `\\'`。

### read_file_content

ファイル内容を自然言語テキストとして取得する。

| パラメータ | 型 | 必須 | 説明 |
|-----------|---|------|------|
| `fileId` | string | Yes | ファイル ID |

**対応 MIME タイプ**:
- Google ドキュメント / スプレッドシート / スライド
- PDF, Word (.docx), Excel (.xlsx), PowerPoint (.pptx)
- ODS, ODP, ODT
- PNG, JPEG

### download_file_content

ファイル内容を base64 エンコード文字列としてダウンロードする。

| パラメータ | 型 | 必須 | 説明 |
|-----------|---|------|------|
| `fileId` | string | Yes | ファイル ID |
| `exportMimeType` | string | 条件付き必須 | Google ネイティブファイル（`application/vnd.google-apps.*`）の場合は必須 |

### get_file_metadata

ファイルのメタデータ（名前・種別・更新日時・サイズ等）を取得する。

| パラメータ | 型 | 必須 | 説明 |
|-----------|---|------|------|
| `fileId` | string | Yes | ファイル ID |
| `excludeContentSnippets` | boolean | No | コンテンツスニペットを除外 |

### get_file_permissions

ファイルの共有権限を取得する。

| パラメータ | 型 | 必須 | 説明 |
|-----------|---|------|------|
| `fileId` | string | Yes | ファイル ID |

### list_recent_files

最近のファイルを一覧表示する。

| パラメータ | 型 | 必須 | 説明 |
|-----------|---|------|------|
| `orderBy` | string | No | `recency` / `lastModified` / `lastModifiedByMe` |
| `pageSize` | integer | No | 返却件数（デフォルト10） |
| `pageToken` | string | No | ページネーション |

## 書き込みツール（承認必須）

### create_file

ファイルを新規作成またはアップロードする。

| パラメータ | 型 | 必須 | 説明 |
|-----------|---|------|------|
| `title` | string | No | ファイルタイトル |
| `textContent` | string | No | テキスト内容（UTF-8） |
| `base64Content` | string | No | base64 エンコード内容 |
| `contentMimeType` | string | No | アップロード内容の MIME タイプ（内容提供時は必須） |
| `parentId` | string | No | 保存先フォルダ ID |
| `disableConversionToGoogleType` | boolean | No | Google タイプへの自動変換を無効化 |

**自動変換**:
- `text/plain` → Google ドキュメント
- `text/csv` → Google スプレッドシート

**空ファイル作成可能**: ドキュメント / スプレッドシート / スライド / フォルダ

### copy_file

既存ファイルのコピーを作成する。

| パラメータ | 型 | 必須 | 説明 |
|-----------|---|------|------|
| `fileId` | string | Yes | コピー元ファイル ID |
| `title` | string | No | コピー先タイトル（省略時: "Copy of {元タイトル}"） |
| `parentId` | string | No | コピー先フォルダ ID |
