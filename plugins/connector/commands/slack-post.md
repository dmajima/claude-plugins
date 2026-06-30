---
description: Slack にメッセージ送信・リアクション・Canvas操作
argument-hint: <送信先チャンネル名 メッセージ内容>
---

ユーザの引数: $ARGUMENTS

connector プラグインの `slack` スキルを **書き込み** で起動してください。

## 動作

1. `Skill` ツールで `connector:slack` を起動し、引数とともに操作種別を明示:
   ```text
   Skill(skill: "connector:slack", args: "書き込み. 対象: $ARGUMENTS")
   ```

## 引数が空の場合

1. `AskUserQuestion` で操作内容を確認する:
   - メッセージ送信
   - メッセージ下書き
   - メッセージ予約送信
   - リアクション追加
   - Canvas 作成/更新

## 制約

- **全書き込み操作で `AskUserQuestion` による承認が必須**
- メッセージは 5000 文字以内
- Canvas 更新時は section_id を事前に確認
