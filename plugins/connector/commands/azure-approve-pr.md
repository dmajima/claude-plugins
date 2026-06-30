---
description: Azure DevOps の PR 承認（vote 値の確認付き）
argument-hint: <PR URL / PR番号> [vote 種別（承認 / 提案付き承認 / 却下 等）]
---

ユーザの引数: $ARGUMENTS

connector プラグインの `azure` スキルを **PR 承認（vote 設定）** に限定して起動してください。このコマンドは操作種別を明示する入口であり、vote 値の確定・対象 PR の提示・`AskUserQuestion` 承認・API 実行はスキル側の定義に従います。

## 動作

1. `Skill` ツールで `connector:azure` を起動し、引数とともに操作種別を明示して渡す:

   ```text
   Skill(skill: "connector:azure", args: "PR 承認（vote 設定）。対象と vote 種別: $ARGUMENTS")
   ```

2. vote 種別の指定がない場合は「承認（vote: 10）」を既定の候補としつつ、**実行前の AskUserQuestion で vote 値と対象 PR を明示して確認する**（スキル側の必須手順）

## 引数が空の場合

ユーザに以下を確認する:

- 対象の PR（PR URL / PR 番号）
- vote 種別（承認 / 提案付き承認 / 作成者の対応待ち / 却下 / 投票リセット）

## 制約

- PR 承認はユーザー本人の意思表示の代行であるため、vote 値を明示した承認なしに実行しない（スキル側ゲートを省略しない）
- このコマンドからは承認以外の書き込み（コメント投稿・PR の complete / abandon）を行わない。コメントを添えたい場合は `/azure-post` を案内する
- `git commit` 以降の操作はこのコマンドからは実行しない
