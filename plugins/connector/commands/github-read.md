---
description: GitHub PR の情報取得・diff 取得・レビュースレッド一覧取得（読み取り専用）
argument-hint: <PR URL / PR番号>
---

ユーザの引数: $ARGUMENTS

connector プラグインの `github` スキルを **読み取り専用** で起動してください。このコマンドは操作種別を明示する入口であり、認証確認・API 実行・結果整形はスキル側の定義に従います。

1. `Skill` ツールで `connector:github` を起動し、引数とともに操作種別を明示:

   Skill(skill: "connector:github", args: "読み取りのみ. 対象: $ARGUMENTS")

2. 書き込み操作が必要な場合は `/connector:github-post` を案内する

対応操作:
- PR メタ情報取得（タイトル・ステータス・レビュアー等）
- PR 変更ファイル一覧・diff 取得・コミット履歴
- レビュースレッド一覧（解決状態含む）

制約:
- 読み取り専用（書き込み操作は `/connector:github-post` を使用）
