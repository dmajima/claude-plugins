# azure references/

Azure DevOps（クラウド / オンプレ TFS）操作スキルの詳細ドキュメント。

## ファイル一覧

| パス | 用途 |
|------|------|
| [host-detection.md](host-detection.md) | ホスト種別判定（クラウド / TFS / 未登録ホスト → ユーザー確認）と URL 解析 |
| [pr-operations.md](pr-operations.md) | PR 操作 API 詳細（取得・作成・コメント・インラインコメント・vote・メタ更新） |
| [workitem-operations.md](workitem-operations.md) | 作業項目操作 API 詳細（取得・コメント投稿。TFS は HTML 変換） |

## 利用ルール

- ホスト判定は必ず [host-detection.md](host-detection.md) の判定順で行う。未登録ホストへは NTLM 認証情報を送信しない（ユーザー本人の明示確認・登録を経た場合のみ続行）
- 認証解決は [../../../references/credentials-precheck.md](../../../references/credentials-precheck.md)、API 呼び出しは [../../../references/safe-api-access.md](../../../references/safe-api-access.md) の原則に必ず従う
- API 手順のコード断片は実行仕様の記述であり、実行時は safe-api-access.md のシークレット取り扱い（netrc・マスク・trap）を併用する
