---
description: Google Drive のファイル検索・読取・メタデータ取得
argument-hint: <ファイル名 or 検索クエリ>
---

ユーザの引数: $ARGUMENTS

connector プラグインの `google-workspace` スキルを **読み取り** で起動してください。

## 動作

1. `Skill` ツールで `connector:google-workspace` を起動し、引数とともに操作種別を明示:
   ```text
   Skill(skill: "connector:google-workspace", args: "読み取り. 対象: $ARGUMENTS")
   ```

## 引数が空の場合

1. `AskUserQuestion` で操作内容を確認する:
   - ファイル検索
   - ファイル内容の読取
   - 最近のファイル一覧
   - ファイルのメタデータ・権限確認

## 制約

- 読み取り専用（ファイル作成・コピーは `/connector:google-post` を使用）
