# Case 01: GitHub PR へのインラインコメント投稿（パターン A）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "https://github.com/contoso/webapp/pull/42 の src/auth/login.ts 30-35 行目に「パスワードのハッシュ化が不足」とコメントして" |
| 引数 | PR URL + ファイルパス + 行範囲 + 投稿本文 |
| フラグ | なし（対話モード・パターン A） |
| 既存状態 | `gh auth status` が終了コード 0 を返す（認証済み） |

## 期待動作

### Phase 1: 認証確認

- `gh auth status` で認証済みを確認

### Phase 2: 操作種別判定

- 「インラインコメント投稿」を **書き込み** と判定

### Phase 3: 承認

- 対象 PR・ファイルパス・行範囲・確定本文を提示し `AskUserQuestion` で承認を得る

### Phase 4: 実行

- `gh pr view 42 --repo contoso/webapp --json headRefOid -q .headRefOid` で HEAD SHA を取得
- `jq -n --arg body ... --arg commit_id ... --arg path ... --argjson start_line 30 --argjson line 35` で JSON body を構築
- `gh api repos/contoso/webapp/pulls/42/comments --input -` で投稿

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 標準出力 | 承認質問 → コメント投稿完了報告（コメント ID・PR URL 付き） |
| 終了状態 | 成功 |

## 分岐の根拠

パターン A でのインラインコメント投稿。承認を経て `gh api` で投稿する標準フロー。
