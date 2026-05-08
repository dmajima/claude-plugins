---
description: カレントセッションのトークン消費量を対話 TUI で表示してクリップボードへコピーする
argument-hint: "[session-uuid]"
allowed-tools: Bash(pwsh:*)
---

# /session-usage — セッション使用量 TUI

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

スキルが `launch.ps1` 経由で別ウィンドウに対話 TUI を起動する。
TUI ウィンドウでは以下のキー操作が可能:

- `[c]` クリップボードコピー
- `[r]` 再集計
- `[q]` / ESC 終了

## 関連

- 実作業スキル: [`../skills/session-usage/SKILL.md`](../skills/session-usage/SKILL.md)
- TUI 仕様: [`../skills/session-usage/references/tui-spec.md`](../skills/session-usage/references/tui-spec.md)
- 実行手順: [`../skills/session-usage/references/procedures.md`](../skills/session-usage/references/procedures.md)
