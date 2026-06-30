---
description: ProjectBoard シートの構造解析（WBSツリー・依存関係・クリティカルパス）
argument-hint: <シートURL / tenant+projectId+シート名>
---

ユーザの引数: $ARGUMENTS

connector プラグインの `projectboard` スキルを **シート全体の構造解析（読み取り専用）** で起動してください。
WBS ツリー・依存関係・クリティカルパス分析（CPM）・サマリを含むレポートを生成します。書き込みは行いません。

## 動作

1. `Skill` ツールで `connector:projectboard` を起動し、引数とともに操作種別を明示して渡す:

   ```text
   Skill(skill: "connector:projectboard", args: "シート全体の構造解析（WBS ツリー・依存関係・クリティカルパス・サマリ）。読み取りのみ。対象: $ARGUMENTS")
   ```

2. スキルはタスクツリー取得後に `analyze_schedule.py` を実行し、Markdown レポート
   （サマリ / WBS ツリー / 依存関係一覧 / CPM 分析 / 警告）を生成・報告する

## 引数が空の場合

ユーザに以下を確認する:

- 対象（シート URL / tenant + projectId + シート名）
- 重視する観点（クリティカルパス・依存関係・全体ツリー・期間サマリ）があるか

## 制約

- このコマンドからは書き込み（タスク追加・更新）を行わない
- 依存関係（先行タスク）が未定義のシートではクリティカルパス経路は算出できず、
  参考情報（duration 上位タスク）の提示になることをユーザーに伝える
- `git commit` 以降の操作はこのコマンドからは実行しない
