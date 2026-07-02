# Case 11: ファイル情報取得（エイリアス URL → 解決成功）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "このリンクのファイル情報を見せて https://example.backlog.jp/alias/file/9876543" |
| 引数 | エイリアス URL（ファイル） |
| フラグ | なし（対話モード） |
| 既存状態 | `~/.claude/credentials.json` に `domains` に `example.backlog.jp` を含む API キーエントリが存在する。プロジェクトキー `PROJ` は会話文脈から既知 |

## 期待動作

### Phase 1: 認証事前確認

- URL からスペースホストを `example.backlog.jp` に確定する
- credentials.json で API キーの存在を確認する

### Phase 2: 操作種別判定

- URL パスに `/alias/file/` を含むため **共有ファイル操作**（読み取り）と判定し、SKILL.md Step 3 へ進む

### Phase 3: エイリアス解決

- パターン B（エイリアス URL）と判定する
- エイリアス URL からスペースホスト `example.backlog.jp` とファイル ID `9876543` を抽出する
- エイリアス Web URL のリダイレクト解決は認証（ブラウザセッション）が必要なため、API キーでは解決できない
- 会話文脈またはユーザーへの確認でプロジェクトキー `PROJ` を取得する

### Phase 4: API 呼び出し（download API ヘッダ取得）

- `GET /api/v2/projects/PROJ/files/9876543?apiKey=***` を実行する（ボディは `-o /dev/null` で破棄）
- レスポンスヘッダから以下を取得する:
  - `Content-Disposition`: ファイル名（URL エンコード済み）
  - `Content-Length`: ファイルサイズ（バイト）
  - `Content-Type`: ファイル種別
- HTTP 200: ファイルとして存在確認完了
- safe-api-access.md の原則に従う: apiKey は `--config` ファイル経由

### Phase 5: 整形報告

- ヘッダから取得したメタデータを提示する:
  - ファイル名（`Content-Disposition` から URL デコード）/ サイズ（`Content-Length` を KB/MB 変換）/ 種別（`Content-Type`）
- ダウンロード操作は未サポートである旨を補足する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし |
| 標準出力（要約） | ファイルのメタデータ（名前・サイズ・種別）の整形報告 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは URL パスの `/alias/file/` パターン検出 → プロジェクトキー取得 → download API ヘッダでメタデータ取得。エイリアスの Web リダイレクト解決は認証要求のため不可。プロジェクトキーが不明な場合は `AskUserQuestion` で確認する。

## 関連ケース

- `case-10_file_list.md`（ダイレクトパス URL からのフォルダ一覧取得。エイリアス解決フェーズをスキップする）
- `case-05_credentials_missing.md`（認証情報なしで API を呼ばず停止するパターン）
