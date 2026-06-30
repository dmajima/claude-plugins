---
description: ailead 共有リンクからデータを取得
argument-hint: <ailead共有URL>
---

ユーザの引数: $ARGUMENTS

connector プラグインの `ailead` スキルを **読み取り** で起動してください。

## 動作

1. `Skill` ツールで `connector:ailead` を起動し、引数とともに操作種別を明示:
   ```text
   Skill(skill: "connector:ailead", args: "読み取り. 対象: $ARGUMENTS")
   ```

## 引数が空の場合

1. `AskUserQuestion` で ailead の共有 URL を確認する
2. URL 取得後、上記と同様に `connector:ailead` を起動する

## 制約

- 読み取り専用（ailead への書き込みは行わない）
- 認証不要の外部共有リンクのみ対応
- パスワード保護リンクは非対応
