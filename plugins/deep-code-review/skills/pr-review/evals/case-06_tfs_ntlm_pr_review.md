# case-06 オンプレ TFS Server (NTLM) の PR レビュー

オンプレ TFS Server URL を指定してレビューするケース。az devops 拡張は TFS 非対応のため curl --ntlm 経路を使用する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "https://tfs.example.com/tfs/Collection/Project/_git/Repo/pullrequest/123 をレビューして" |
| モード | 対話 |

## 分岐の根拠

SKILL.md Step 1 / Step 1.1 のホスト判定でオンプレ TFS を検出し、`connector:azure` へ PR 操作を委譲する（NTLM 認証・netrc・REST 呼び出しは connector 内部実装。`azure-devops-tfs-ntlm.md` は connector 内部のデバッグ用リファレンス）。認証情報取得は connector 委譲（U12・`credentials-precheck.md` の委譲モデル）。

## 期待動作

- URL からホストを TFS Server と判定する（`pr-identifier-validation.md` の TFS 正規表現 + connector:azure の host-detection.md へ委譲。pr-review から HTTP プローブはしない）
- az devops 拡張は使用しない（TFS 非対応のため。connector:azure が curl --ntlm 経路を用いる）
- **認証情報取得は connector:azure に委譲**し、connector が credentials-manager ストア（`.claude/.local/plugins/credentials-manager/credentials.json`。後方互換で従来パスも）から `tfs-password` を解決する（pr-review は `credentials.json` を直接参照しない・U12）
- connector:azure が内部で curl --ntlm --netrc-file 経由の REST API 呼び出し・NETRC 書き込み前の host ホワイトリスト検証（urls[] 照合）を行う（pr-review は直接実行しない）
- レビュー結果を connector 経由で PR にインラインコメントとして投稿する
- state.yaml を `.claude/.local/plugins/deep-code-review/{branch}/` に保存する
- （以下は検出してはならない誤り）
    - pr-review が `credentials.json` を直接読む / 直接 curl --ntlm を実行する（connector 委譲違反・U12）
    - connector 接続時に credentials-manager スキルを別途直接呼び出す（connector が抽象化層・不要）

## 関連ケース

- case-02: クラウド Azure DevOps（az devops 経路）
- case-07: 投稿前バリデーション
