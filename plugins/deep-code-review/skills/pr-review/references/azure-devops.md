# Azure DevOps PR 操作（インデックス・薄）

> **位置付け**: 子ファイルへの **薄インデックス**。詳細は各子ファイル参照。
>
> **委譲設計**: Azure DevOps の PR 操作（情報取得・コメント投稿・スレッド操作）は **connector プラグインの `azure` スキルに委譲**。pr-review は投稿内容の組み立て（レビュー結果の整形・テンプレート適用・バリデーション）を担当し、実際の API 操作は `Skill(skill: "connector:azure", args: "...")` 経由で実行する。本インデックス配下のファイルは、API 仕様の参照（デバッグ・トラブルシューティング時）と GitHub PR 操作（connector 未対応）のために維持する。

| ホスト種別 | 認証経路 | 操作経路 | 参照ファイル |
|-----------|---------|---------|------------|
| クラウド `dev.azure.com` / `*.visualstudio.com` | MS アカウント (`az login`) | **connector:azure に委譲** | [`azure-devops-cloud.md`](azure-devops-cloud.md) |
| オンプレ TFS（`tfs.<company>.com` 等） | NTLM | **connector:azure に委譲** | [`azure-devops-tfs-ntlm.md`](azure-devops-tfs-ntlm.md) |
| 共通仕様（status / commentType / URL 解析 / レート制限） | 共通 | 共通 | [`azure-devops-common.md`](azure-devops-common.md) |

ホスト判別の正規表現と判別フローは `${CLAUDE_SKILL_DIR}/references/pr-identifier-validation.md` 参照。

## connector:azure への委譲パターン

pr-review から connector:azure を呼ぶ際の標準パターン:

```text
# PR 情報取得（読み取り）
Skill(skill: "connector:azure", args: "読み取りのみ。PR URL: <url> の PR メタ情報を取得して")

# スレッド一覧取得（読み取り）
Skill(skill: "connector:azure", args: "読み取りのみ。PR URL: <url> のスレッド一覧を取得して")

# インラインコメント投稿（書き込み・安全ゲートスキップ）
Skill(skill: "connector:azure", args: "PR URL: <url> にインラインコメントを投稿。ファイル: <path>, 開始行: <n>, 終了行: <m>, 本文: <content>。render-check 通過済み。承認済み。")

# 全体コメント投稿（書き込み・安全ゲートスキップ）
Skill(skill: "connector:azure", args: "PR URL: <url> にコメントスレッドを投稿。本文: <content>。render-check 通過済み。承認済み。")

# スレッドステータス変更（書き込み・安全ゲートスキップ）
Skill(skill: "connector:azure", args: "PR URL: <url> のスレッド <threadId> のステータスを <status> に変更。承認済み。")

# 既存スレッドへの返信（書き込み・安全ゲートスキップ）
Skill(skill: "connector:azure", args: "PR URL: <url> のスレッド <threadId> に返信。本文: <content>。render-check 通過済み。承認済み。")
```

pr-review は自身のワークフローで render-check（Step 7 投稿前バリデーション）とユーザー承認（Step 7 投稿確認）を実施済みのため、connector 呼び出し時に「render-check 通過済み。承認済み。」を明示する。
