# Case 02: 課題検索（キーワード + プロジェクト指定）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "Backlog の PROJ プロジェクトで『ログイン』に関する課題を検索して" |
| 引数 | プロジェクトキー `PROJ` / 検索キーワード `ログイン`（スペースは `example.backlog.jp`） |
| フラグ | なし（対話モード） |
| 既存状態 | `~/.claude/credentials.json` に `domains` に `example.backlog.jp` を含む API キーエントリ（`value` 非空）が存在する |

## 期待動作

### Phase 1: 認証事前確認

- 対象スペースのホストを `example.backlog.jp` に確定し、credentials.json の `domains` 照合で API キーの存在を確認する

### Phase 2: 操作種別判定

- 「課題検索」を **読み取り** と判定し、SKILL.md Step 3 へ進む

### Phase 3: プロジェクトキー → projectId 数値解決

- 課題検索 API の `projectId[]` パラメータは数値 ID のみ受け付けるため、先に `GET /api/v2/projects/PROJ` を呼び、レスポンスの `id`（数値）を取得する（api-read.md 操作 1）

### Phase 4: 課題検索の実行

- `GET /api/v2/issues?projectId[]={id}&keyword={kw}&count=20&sort=updated&order=desc` を呼び出す
- `keyword` の値 `ログイン` は `jq -rn --arg v "$VALUE" '$v|@uri'` で URL エンコードしてからクエリに連結する（日本語の生埋め込み禁止）
- curl の呼び出しは case-01 と同じ共通パターン（`--config` 経由・`--max-time 30`・HTTP コード分岐）

### Phase 5: 検索結果の整形報告

- ヒットした課題を `課題キー / 件名 / ステータス / 担当者 / 期限 / 更新日時` の一覧表で提示する
- 件数と絞り込み条件（プロジェクト = PROJ、キーワード = ログイン、件数上限 20、更新日時降順）を明記する
- 各課題の URL は `https://example.backlog.jp/view/{issueKey}` 形式

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（一時ファイルは処理終了時に削除済み） |
| 標準出力（要約） | ヒット件数 + 絞り込み条件 + 課題一覧表（0 件の場合は「該当なし」と検索条件の見直し提案） |
| 終了状態 | 成功（特定の課題の詳細取得に進むかを確認して終了） |

## 分岐の根拠

このケースが分岐するトリガーは 操作種別 = 読み取りのうち検索系操作（キーワード + プロジェクト指定）である。単一課題取得（case-01）と異なり、`projectId[]` が数値 ID 必須のため `GET /api/v2/projects/{projectIdOrKey}` によるキー → ID 解決フェーズを経由する。

## 関連ケース

- `case-01_issue_get.md`（課題キー直指定の取得。`issueIdOrKey` には課題キーがそのまま使えるため ID 解決が不要）
- `case-04_status_update.md`（同じ一覧系 API を ID 解決に使う書き込みケース）
- `case-05_credentials_missing.md`（認証事前確認に失敗した場合の停止動作）
