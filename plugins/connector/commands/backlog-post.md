---
description: Backlog 課題へのコメント投稿（検証・承認ゲート付き）
argument-hint: <課題キー / 課題URL> <投稿内容の指示>
---

ユーザの引数: $ARGUMENTS

connector プラグインの `backlog` スキルを **コメント投稿** に限定して起動してください。このコマンドは操作種別を明示する入口であり、記法判定（textFormattingRule）・render-check 検証・`AskUserQuestion` 承認・API 実行はスキル側の書き込みゲートに従います。

## 動作

1. `Skill` ツールで `connector:backlog` を起動し、引数とともに操作種別を明示して渡す:

   ```text
   Skill(skill: "connector:backlog", args: "コメント投稿。対象と内容: $ARGUMENTS")
   ```

2. 投稿本文の組み立て・検証・承認・投稿はスキル側の Step 4（書き込み系の実行）に委ねる

## 引数が空の場合

ユーザに以下を確認する:

- 投稿先の課題（課題キー / 課題 URL）
- 投稿する内容（本文そのもの、または組み立ての指示）

## 制約

- このコマンドからはコメント投稿以外の書き込み（ステータス・担当者等の変更）を行わない。メタ情報の変更が必要な場合は `/backlog-update` を案内する
- render-check 未通過・ユーザー未承認での投稿は行わない（スキル側ゲートを省略しない）
- `git commit` 以降の操作はこのコマンドからは実行しない
