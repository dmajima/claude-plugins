# Case 06: TFS PR コメント投稿の承認で「中止」選択（threads API を発行せず終了）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "PR !123 に進捗コメントを投稿して"（投稿本文は会話中に提示済み。対象は直近で操作していた `tfs.example.local` の WebApp/webapp リポジトリと特定できる） |
| 引数 | PR ID `123` + 投稿本文（ホスト `tfs.example.local` / プロジェクト `WebApp` / リポジトリ `webapp`） |
| フラグ | なし（対話モード） |
| 既存状態 | `~/.claude/credentials.json` の `tfs-password` エントリに `domains: ["tfs.example.local"]`・`username`・`value` が登録済み / PR 123 は active / 本文に記法不一致・自動リンク要素・機密情報なし（render-check は PASS になる） |

## 期待動作

### Phase 1: 認証事前確認とホスト判定

- `tfs-password` エントリの `username` と `value` が非空であることを確認する（値そのものは表示しない）
- ホスト `tfs.example.local` は `tfs-password` の `domains[]` に登録済み → 種別 = オンプレ TFS / 操作手段 = `curl --ntlm --netrc-file` / api-version = 6.0 と判定する

### Phase 2: 操作種別判定

- 「PR コメント投稿」を **書き込み（本文あり）** と判定し、SKILL.md Step 4（書き込み系の実行）へ進む

### Phase 3: render-check ゲート（必須）

- 投稿本文 + ターゲット `ado-markdown` で `render-check` スキルを実行する
- 5 カテゴリ（NOTATION / AUTOLINK / STRUCTURE / SECRET / SIZE）全てが検査され、総合判定 **PASS** が返る

### Phase 4: 承認（ユーザーが中止を選択）

- 対象 PR（PR 123・タイトル）・操作内容（新規スレッドとしてコメント投稿）・確定本文を提示し、`AskUserQuestion` で承認を求める
- ユーザーが「中止」を選択する

### Phase 5: 中止の報告

- `POST {base}/WebApp/_apis/git/repositories/webapp/pullrequests/123/threads?api-version=6.0` を **発行しない**（書き込み API リクエスト 0 件。render-check PASS 済みでも承認なしでは投稿しない）
- 投稿を中止した旨と中止した操作内容（対象 PR・操作種別・本文は送信されていないこと）を報告して終了する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（PR 123 にコメントスレッドは作成されない） |
| 標準出力（要約） | render-check 結果（PASS）→ 承認質問 → 投稿を中止した旨 + 中止した操作内容（対象 PR・操作種別・本文未送信）の報告 |
| 終了状態 | 中止（threads API の発行数 0） |

## 分岐の根拠

このケースが分岐するトリガーは AskUserQuestion の選択 = 中止 である。case-02 と同じく render-check PASS から承認質問へ進むが、ユーザーが承認ではなく中止を選択するため、threads API が発行されずに終了する。

## 関連ケース

- `case-02_pr_comment_cloud.md`（同じ PR コメント投稿で承認が選択され、投稿完了報告まで進む対比。ホスト種別はクラウド）
- `case-01_pr_create_tfs.md`（同じ TFS ホスト・NTLM 経路の書き込みで承認が選択され、POST まで進む対比）
