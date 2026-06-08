---
description: セッションのトークン消費量を表示し、コピー・再集計を対話メニューで操作
argument-hint: "[session-uuid]"
allowed-tools: Bash(bash:*)
---

# /session-usage — セッション使用量

ユーザの引数: $ARGUMENTS

`/session-usage` コマンド本体は **トリガーと引数解釈のみ** を担当し、実作業は
`session-usage` スキルへ委譲する（責務分離）。

## 引数解釈

| 引数 | 解釈 |
|-----|------|
| 空 | カレントセッション（`$env:CLAUDE_CODE_SESSION_ID` → 最新 mtime） |
| 36 文字 UUID 形式 | 該当セッションを集計対象とする |
| その他 | 警告表示後、空扱いで進行 |

UUID 検証は `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$` で行う。

## スキル委譲

引数解釈完了後、`session-usage` スキルを起動する:

```text
Skill(skill: "session-usage", args: "$ARGUMENTS")
```

スキルが以下を実施する:

1. `aggregate.sh -Stdout` で集計結果を Claude のコンテキストに取得（自動コピーは行わない）
2. `AskUserQuestion` で「クリップボードへコピー / 再集計 / 終了」の 3 択を提示し、
   各オプションの `preview` フィールドに集計結果全文を埋め込む（折りたたまれない表示）
3. 「コピー」選択時のみ `aggregate.sh -Copy` を実行
4. 「終了」が選ばれるまで選択肢を再提示し続ける

## 関連

- 実作業スキル: [`../skills/session-usage/SKILL.md`](../skills/session-usage/SKILL.md)
- 実行手順: [`../skills/session-usage/references/procedures.md`](../skills/session-usage/references/procedures.md)
