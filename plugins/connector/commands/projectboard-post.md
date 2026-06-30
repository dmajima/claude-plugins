---
description: HUE ProjectBoard へのタスク追加（承認必須）
argument-hint: <対象シート + 追加するタスクの内容（タイトル・親・位置・種別）>
---

ユーザの引数: $ARGUMENTS

connector プラグインの `projectboard` スキルを **タスク追加** で起動してください。
追加内容の提示と AskUserQuestion 承認を経てから addNode API を実行します。

## 動作

1. `Skill` ツールで `connector:projectboard` を起動し、引数とともに操作種別を明示して渡す:

   ```text
   Skill(skill: "connector:projectboard", args: "タスク追加。対象と内容: $ARGUMENTS")
   ```

2. 親パッケージ・挿入位置・タスク種別（TASK / PACKAGE / MILESTONE）の解決はスキル側が
   現状のシートを読み取ったうえで行い、曖昧な場合は候補を提示して確認する

## 引数が空の場合

ユーザに以下を確認する:

- 対象シート（URL / tenant + projectId + シート名）
- 追加するタスクのタイトル
- 配置先（親パッケージ・挿入位置）と種別（TASK / PACKAGE / MILESTONE。省略時 TASK）

## 制約

- **ユーザー承認なしで追加を実行しない**（スキル側の書き込みゲートを必ず経由する）
- 追加後はシートを再取得して反映を検証する（書き込み API の一部は推定仕様のため必須）
- 依頼された 1 件のみ追加する（複数一括追加はユーザーの明示指示 + 対象一覧の承認がある場合のみ）
- `git commit` 以降の操作はこのコマンドからは実行しない
