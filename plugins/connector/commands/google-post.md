---
description: Google Drive にファイル作成・コピー
argument-hint: <ファイルタイトル ファイル種別>
---

ユーザの引数: $ARGUMENTS

connector プラグインの `google-workspace` スキルを **書き込み** で起動してください。

## 動作

1. `Skill` ツールで `connector:google-workspace` を起動し、引数とともに操作種別を明示:
   ```text
   Skill(skill: "connector:google-workspace", args: "書き込み. 対象: $ARGUMENTS")
   ```

## 引数が空の場合

1. `AskUserQuestion` で操作内容を確認する:
   - ファイル新規作成（ドキュメント / スプレッドシート / スライド）
   - テキスト/CSVファイルのアップロード
   - 既存ファイルのコピー

## 制約

- **全書き込み操作で `AskUserQuestion` による承認が必須**
