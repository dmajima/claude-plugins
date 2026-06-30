# Case 07: TFS PR へのインラインコメント投稿（threadContext 付き）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "https://tfs.example.com/DefaultCollection/MyProject/_git/myrepo/pullrequest/45 にインラインコメントを投稿。ファイル: /src/Controllers/OrderController.cs, 開始行: 120, 終了行: 135, 本文: SQL インジェクションの可能性があります。パラメータ化クエリを使用してください。" |
| 引数 | PR URL + ファイルパス + 行範囲 + 投稿本文 |
| フラグ | なし（対話モード・パターン A） |
| 既存状態 | `~/.claude/credentials.json` に `tfs-password` エントリ（`tfs.example.com` が `urls` / `domains` に登録済み）。PR 45 は active |

## 期待動作

### Phase 1: 呼び出し元判別

- パターン A（ユーザー直接呼び出し）と判別する（args に「render-check 通過済み」「承認済み」を含まない）

### Phase 2: 認証事前確認とホスト判定

- `tfs.example.com` が credentials.json の `tfs-password.domains` に含まれることを確認
- ホスト種別 = オンプレ TFS / 操作手段 = `curl --ntlm --netrc-file` / api-version = 6.0 と判定

### Phase 3: 操作種別判定

- 「PR インラインコメント投稿」を **書き込み（本文あり）** と判定

### Phase 4: render-check ゲート

- 投稿本文 + ターゲット `ado-markdown` で `render-check` を実行し PASS を確認

### Phase 5: 承認

- 対象 PR・ファイルパス・行範囲・確定本文を提示し `AskUserQuestion` で承認を得る

### Phase 6: 実行と結果検証

- `threadContext`（`filePath` + `rightFileStart` + `rightFileEnd`）を含む body を `jq -n --rawfile` で構築
- `filePath` は `--rawfile` 経由で渡す（`--arg` は MSYS パス自動変換で破綻する）
- `curl --ntlm --netrc-file "$NETRC"` で POST。一時ファイルは `cleanup_secrets` の trap で管理
- レスポンスからスレッド `id` を取得し、PR URL とともに投稿成功を報告

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（PR 45 にインラインコメントスレッドが 1 件作成される） |
| 標準出力（要約） | render-check 結果（PASS）→ 承認質問 → インラインコメント投稿完了報告（スレッド ID・ファイルパス・行範囲・PR URL 付き） |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは **threadContext を含むコメント投稿**（インラインコメント）である。通常の PR 全体コメント（case-02）と異なり、body に `threadContext.filePath` / `rightFileStart` / `rightFileEnd` を含め、特定ファイルの特定行範囲にコメントを紐付ける。

## 関連ケース

- `case-02_pr_comment_cloud.md`（threadContext なしの PR 全体コメント。クラウドの対比）
- `case-08_delegation_inline_comment.md`（パターン B 委譲でインラインコメントを投稿する場合）
