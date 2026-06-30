---
description: Azure DevOps の PR / 作業項目へのコメント投稿
argument-hint: <PR / 作業項目の URL・番号> <投稿内容の指示>
---

ユーザの引数: $ARGUMENTS

connector プラグインの `azure` スキルを **コメント投稿** に限定して起動してください。このコマンドは操作種別を明示する入口であり、投稿先判定（PR スレッド / クラウド作業項目 / TFS 作業項目）・render-check 検証・`AskUserQuestion` 承認・API 実行はスキル側の書き込みゲートに従います。

## 動作

1. `Skill` ツールで `connector:azure` を起動し、引数とともに操作種別を明示して渡す:

   ```text
   Skill(skill: "connector:azure", args: "コメント投稿（PR スレッドまたは作業項目）。対象と内容: $ARGUMENTS")
   ```

2. 投稿先のレンダリング方式の決定はスキル側に委ねる（PR・クラウド作業項目 = Markdown / **TFS 作業項目 = HTML**。Markdown 下書きは render-check が変換案を提示する）

## 引数が空の場合

ユーザに以下を確認する:

- 投稿先（PR URL・PR 番号 / 作業項目 URL・ID）
- 投稿する内容（本文そのもの、または組み立ての指示）

## 制約

- このコマンドからはコメント投稿以外の書き込み（PR 作成・承認・メタ情報更新・作業項目のフィールド変更）を行わない。PR 作成は `/azure-create-pr`、承認は `/azure-approve-pr` を案内する
- render-check 未通過・ユーザー未承認での投稿は行わない（スキル側ゲートを省略しない）
- `git commit` 以降の操作はこのコマンドからは実行しない
