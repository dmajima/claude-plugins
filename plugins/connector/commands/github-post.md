---
description: GitHub PR へのコメント投稿・Pending Review・スレッド resolve/unresolve
argument-hint: <PR URL / PR番号> <操作内容>
---

ユーザの引数: $ARGUMENTS

connector プラグインの `github` スキルを **書き込みモード** で起動してください。このコマンドは操作種別を明示する入口であり、認証確認・承認・API 実行・結果検証はスキル側の定義に従います。

1. `Skill` ツールで `connector:github` を起動し、引数とともに操作種別を明示:

   Skill(skill: "connector:github", args: "書き込み. 対象: $ARGUMENTS")

2. 読み取り専用操作が必要な場合は `/connector:github-read` を案内する

対応操作:
- インラインコメント投稿（ファイルパス・行範囲指定）
- Pending Review 一括投稿（複数コメントまとめ）
- PR 全体コメント投稿
- 既存コメントへの返信
- レビュースレッド resolve / unresolve

制約:
- 書き込み系操作。実行前にユーザー承認が必要
