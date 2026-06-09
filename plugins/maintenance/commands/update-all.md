---
description: 公式 CLI でマーケットプレイス・プラグインを全プロジェクト一括最新化
argument-hint: "[--dry-run]"
---

ユーザの引数: $ARGUMENTS

`/update-all` コマンド本体は **トリガーと引数解釈のみ** を担当し、実作業は
`plugin-updater` スキルへ委譲する（責務分離 ADR-PU-001 / ADR-PU-008）。

どのプロジェクトから実行しても、**全てのプロジェクトのプラグインが最新化される**。
現在のプロジェクトだけを更新したい場合は `/update` を使用する。

## 引数解釈

| 引数 | 解釈ルール |
|-----|----------|
| 空 | `mode = normal` |
| `--dry-run` | `mode = dry-run` |

## スキル委譲

引数解釈完了後、`plugin-updater` スキルを起動して結果を待つ:

```text
Skill(skill: "plugin-updater", args: "mode=<mode> target=all")
```

スキルが Phase A-0〜G を実行し、結果報告（Phase F のサマリ + 詳細テーブル）と
失敗時の対話結果（Phase G）をユーザに直接返す。コマンド本体は結果を加工せず透過する。

## 関連

- 現在のプロジェクトのみ更新: [`update.md`](update.md)（`/update`）
- 実作業スキル: [`../skills/plugin-updater/SKILL.md`](../skills/plugin-updater/SKILL.md)
- 設計判断記録: [`../skills/plugin-updater/references/architecture-decisions.md`](../skills/plugin-updater/references/architecture-decisions.md)
- グローバルルール `~/.claude/rules/claude/plugin-auto-update.md`（自動更新ポリシー）
- `extension-toolkit:marketplace-toolkit`（マーケットプレイス本体管理）
- `extension-toolkit:marketplace-publish`（マーケットプレイスへの公開）
