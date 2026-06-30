---
description: Azure DevOps の PR 情報・スレッドの読み取り
argument-hint: <PR URL / PR番号>
---

ユーザの引数: $ARGUMENTS

connector プラグインの `azure` スキルを **読み取り専用** で起動してください。このコマンドは操作種別を明示する入口であり、ホスト種別判定（クラウド / TFS）・認証確認・API 実行・結果整形はスキル側の定義に従います。

## 動作

1. `Skill` ツールで `connector:azure` を起動し、引数とともに操作種別を明示して渡す:

   ```text
   Skill(skill: "connector:azure", args: "読み取りのみ（PR 情報・スレッド・作業項目の取得）。対象: $ARGUMENTS")
   ```

2. PR 番号のみの指定では、組織 / プロジェクト / リポジトリの補完（直近の操作対象・カレントリポジトリの remote）はスキル側に委ねる

## 引数が空の場合

ユーザに以下を確認する:

- 対象（PR URL / PR 番号。作業項目の読み取りなら作業項目 URL / ID）
- 取得したい情報（PR 概要・説明・コメントスレッド・レビュアー状況）

## 制約

- このコマンドからは書き込み（PR 作成・コメント投稿・承認・更新）を行わない。書き込みの依頼が含まれる場合は `/azure-create-pr` / `/azure-post` / `/azure-approve-pr` を案内する
- `git commit` 以降の操作はこのコマンドからは実行しない
