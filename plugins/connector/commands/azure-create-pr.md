---
description: Azure DevOps の PR 作成（検証・承認ゲート付き）
argument-hint: <ソースブランチ> <ターゲットブランチ> [タイトル・説明の指示]
---

ユーザの引数: $ARGUMENTS

connector プラグインの `azure` スキルを **PR 作成** に限定して起動してください。このコマンドは操作種別を明示する入口であり、ブランチ存在確認・重複 PR 確認・説明文の render-check 検証・`AskUserQuestion` 承認・API 実行はスキル側の書き込みゲートに従います。

## 動作

1. `Skill` ツールで `connector:azure` を起動し、引数とともに操作種別を明示して渡す:

   ```text
   Skill(skill: "connector:azure", args: "PR 作成。指定: $ARGUMENTS")
   ```

2. 対象リポジトリ・組織の補完（カレントリポジトリの remote 等）、タイトル・説明の組み立て、事前確認、承認、作成はスキル側の Step 4（書き込み系の実行）に委ねる

## 引数が空の場合

ユーザに以下を確認する:

- ソースブランチとターゲットブランチ
- PR のタイトル・説明（または組み立ての指示。下書き = draft の要否）

## 制約

- このコマンドからは PR 作成以外の書き込み（コメント投稿・承認・complete）を行わない。投稿は `/azure-post`、承認は `/azure-approve-pr` を案内する
- 同一ソース → ターゲットの active PR が既に存在する場合は重複作成せず既存 PR を提示する（スキル側の事前確認に従う）
- render-check 未通過・ユーザー未承認での作成は行わない（スキル側ゲートを省略しない）
- `git commit` 以降の操作はこのコマンドからは実行しない
