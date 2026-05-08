---
description: カレントセッションのトークン消費量を Claude UI に表示し、自動でクリップボードへコピーする
argument-hint: "[session-uuid]"
allowed-tools: Bash(pwsh:*)
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

1. `aggregate.ps1 -Stdout -Copy` で集計結果を Claude UI に表示
2. 同時に整形済み文字列をクリップボードへ自動コピー
3. `AskUserQuestion` で「再集計 / 終了」を選択させる

## 関連

- 実作業スキル: [`../skills/session-usage/SKILL.md`](../skills/session-usage/SKILL.md)
- 実行手順: [`../skills/session-usage/references/procedures.md`](../skills/session-usage/references/procedures.md)
