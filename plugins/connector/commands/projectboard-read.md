---
description: HUE ProjectBoard のタスク読み取り・一覧 CSV 化（読み取り専用）
argument-hint: <シートURL / tenant+projectId / タスクID（SAMPLE-67 等）>
---

ユーザの引数: $ARGUMENTS

connector プラグインの `projectboard` スキルを **読み取り専用** で起動してください。
タスクツリーの取得・特定タスクの参照・タスク一覧の CSV 化のみを行い、書き込みは行いません。

## 動作

1. `Skill` ツールで `connector:projectboard` を起動し、引数とともに操作種別を明示して渡す:

   ```text
   Skill(skill: "connector:projectboard", args: "読み取りのみ（タスク取得 / 特定タスク参照 / CSV 化）。対象: $ARGUMENTS")
   ```

2. 引数の解釈（URL → シート特定、タスク ID → 該当タスク抽出、「CSV で」→ tasks_to_csv 等）は
   スキル側の操作種別判定に委ねる

## 引数が空の場合

ユーザに以下を確認する:

- 対象（シート URL / tenant + projectId / シート名）
- 取得したい情報（タスク一覧 CSV・特定タスクの詳細・シート一覧）

## 制約

- このコマンドからは書き込み（タスク追加・更新）を行わない。書き込みが必要な場合は
  `/connector:projectboard-post` / `/connector:projectboard-update` を案内する
- シート全体の構造解析（クリティカルパス等）は `/connector:projectboard-sheet` が担当する
- `git commit` 以降の操作はこのコマンドからは実行しない
