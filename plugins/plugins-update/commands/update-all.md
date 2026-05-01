---
description: 公式 CLI でマーケットプレイス・プラグインを一括最新化
argument-hint: "[--dry-run] [--scope <user|project|local>]"
---

ユーザの引数: $ARGUMENTS

`/update-all` コマンド本体は **トリガーと引数解釈のみ** を担当し、実作業は
`plugin-updater` スキルへ委譲する（責務分離 ADR-PU-001 / ADR-PU-008）。

## 引数解釈

| 引数 | 解釈ルール |
|-----|----------|
| 空 | `mode = normal`、`scope = all` |
| `--dry-run` | `mode = dry-run`、`scope` は別途解釈（既定 `all`） |
| `--scope user` / `--scope project` / `--scope local` | `scope = <値>` |
| `--scope all` | `scope = all`（明示） |

`--dry-run` と `--scope` は併用可能。
不正な `--scope` 値（例: `--scope foo`）が渡された場合は処理を実行せず以下の形式でエラーを返す
（スキル側でも検証されるが、コマンド側で早期失敗させる）:

```text
エラー: 不正な --scope 値 "foo" が指定されました。有効な値は user / project / local です。
```

## スキル委譲

引数解釈完了後、`plugin-updater` スキルを起動して結果を待つ:

```text
Skill(skill: "plugin-updater", args: "mode=<mode> scope=<scope>")
```

スキルが Phase A-0〜G を実行し、結果報告（Phase F のサマリ + 詳細テーブル）と
失敗時の対話結果（Phase G）をユーザに直接返す。コマンド本体は結果を加工せず透過する。

## 関連

- 実作業スキル: [`../skills/plugin-updater/SKILL.md`](../skills/plugin-updater/SKILL.md)
- 設計判断記録: [`../skills/plugin-updater/references/architecture-decisions.md`](../skills/plugin-updater/references/architecture-decisions.md)
- グローバルルール `~/.claude/rules/claude/plugin-auto-update.md`（自動更新ポリシー）
- `extension-toolkit:marketplace-toolkit`（マーケットプレイス本体管理）
- `extension-toolkit:marketplace-publisher`（マーケットプレイスへの公開）
