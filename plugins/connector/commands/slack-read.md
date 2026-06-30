---
description: Slack のチャンネル・メッセージ・ユーザーを検索・読取
argument-hint: <チャンネル名 or 検索クエリ or ユーザー名>
---

ユーザの引数: $ARGUMENTS

connector プラグインの `slack` スキルを **読み取り** で起動してください。

## 動作

1. `Skill` ツールで `connector:slack` を起動し、引数とともに操作種別を明示:
   ```text
   Skill(skill: "connector:slack", args: "読み取り. 対象: $ARGUMENTS")
   ```

## 引数が空の場合

1. `AskUserQuestion` で操作内容を確認する:
   - チャンネル検索
   - メッセージ検索
   - チャンネルのメッセージ読取
   - ユーザー検索

## 制約

- 読み取り専用（書き込み操作は `/connector:slack-post` を使用）
- プライベートチャンネル・DM の検索はユーザー同意を確認
