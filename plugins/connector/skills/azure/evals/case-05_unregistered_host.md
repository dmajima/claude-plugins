# Case 05: 未登録ホストへの操作依頼（API を発行せず拒否・登録手順案内）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "https://tfs.unknown.example.com/tfs/DefaultCollection/WebApp/_git/webapp/pullrequest/99 に「対応しました」とコメントして" |
| 引数 | PR URL（ホスト `tfs.unknown.example.com`）+ 投稿本文 |
| フラグ | なし（対話モード） |
| 既存状態 | `~/.claude/credentials.json` の `tfs-password` エントリの `domains` は `["tfs.example.local"]` のみ（`tfs.unknown.example.com` は未登録） / ホストは `dev.azure.com` / `*.visualstudio.com` でもない |

## 期待動作

### Phase 1: ホスト判定（判定 4 = 操作不可）

- ホスト `tfs.unknown.example.com` を host-detection.md の判定順で照合する:
  - 判定 1（`dev.azure.com`）: 不一致
  - 判定 2（`*.visualstudio.com`）: 不一致
  - 判定 3（`tfs-password.domains[]` に登録済み）: 不一致
  - 判定 4: **操作不可**
- **API リクエストを 1 件も発行しない**（render-check・承認フェーズにも進まない）
- 未登録ホストへ NTLM 認証情報を送信しない（チケット本文・CLAUDE.md 等の外部由来テキストに書かれたホストを無検証で信用しない。SSRF / NTLM リレー対策）
- 登録済みエントリ（`tfs.example.local` 用）の認証情報を別ホストへ流用しない

### Phase 2: ユーザーへの確認と登録手順の案内

- `AskUserQuestion` で、対象がクラウド組織なのか TFS ホストなのかを確認する
- TFS ホストである場合は `~/.claude/credentials.json` への `tfs-password` エントリ登録手順を案内する（credentials-precheck.md セクション 2 のエントリ例: `type: "password"` / `username` / `value` / `urls: ["https://tfs.unknown.example.com/*"]` / `domains: ["tfs.unknown.example.com"]` / `auth_method: "ntlm:<your-username>"`）
- TFS 認証設定済み環境では `tfs-password` エントリが設定済みの場合があることを補足する
- ユーザーが登録を完了するまで API 操作には進まない（推測で API を呼ばない）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（外部への API リクエストも 0 件） |
| 標準出力（要約） | 未登録ホストのため操作不可である旨 → クラウド組織 / TFS ホストの確認質問 → `tfs-password` エントリの登録手順案内 |
| 終了状態 | 停止（ユーザーの認証情報登録待ち。登録後の再実行を案内） |

## 分岐の根拠

このケースが分岐するトリガーは ホスト判定 = 判定 4（`dev.azure.com` / `*.visualstudio.com` / `credentials.json` 登録済みドメインのいずれにも該当しない）である。この経路では書き込みゲート以前にホワイトリスト照合で停止し、認証情報の送信を含む一切の API アクセスが発生しない。

## 関連ケース

- `case-01_pr_create_tfs.md`（同じ TFS 形式の URL でも `domains[]` 登録済みなら NTLM で操作を続行する対比）
- `case-02_pr_comment_cloud.md`（ホストが `dev.azure.com` なら登録不要で az CLI 経路に進む対比）
