---
description: 設計書・モックと claude.ai/design の同期状況を表示
argument-hint: "[--local]"
---

ユーザの引数: $ARGUMENTS

`/design-status` コマンドは、ローカル正本と claude.ai/design の同期状況を表示する。
読み取り専用で、ローカルもリモートも変更しない。

## 引数解釈

| 引数 | 解釈ルール |
|-----|----------|
| 空 | 未反映一覧 + リモートとのドリフト照合まで実施する |
| `--local` | ローカルの未反映一覧のみ表示する（リモート照合なし・高速） |
| その他 | 自然言語として扱い、スキルへそのまま渡す |

## 前提条件

`.claude/design-bridge.json` が存在すること。未導入の場合はスキル側が
`/design-init` を案内する。リモート照合には design-system 認可が必要だが、
未認可の場合はローカル側の情報のみ報告される。

## スキル委譲

引数解釈完了後、`design-status` スキルを起動して結果を待つ:

```text
Skill(skill: "design-bridge:design-status", args: "<引数>")
```

このコマンドはユーザへの問い合わせを行わない（読み取りのみのため）。

## 関連

- 反映: [`design-push.md`](design-push.md)（`/design-push`）
- 取り込み: [`design-pull.md`](design-pull.md)（`/design-pull`）
- 実作業スキル: [`../skills/design-status/SKILL.md`](../skills/design-status/SKILL.md)
