---
description: 現在のプロジェクトの Project / Local スコーププラグインを最新化
argument-hint: "[--dry-run]"
---

ユーザの引数: $ARGUMENTS

`/update` コマンドは、**現在のプロジェクト** の Project / Local スコーププラグインのみを
更新する。マーケットプレイス更新・User スコープ更新は行わない。

全プロジェクトを一括更新したい場合は `/update-all` を使用する。

## 引数解釈

| 引数 | 解釈ルール |
|-----|----------|
| 空 | `mode = normal` |
| `--dry-run` | `mode = dry-run` |

## 前提条件

git リポジトリ配下で実行されている必要がある。リポジトリ外で実行された場合、
スキル側の Phase A-Repo でエラーが返される（コマンド側では事前検証を行わない。ADR-PU-008 の
行数制約との整合のため、前提条件の検証はスキル側に委譲する設計）。

## スキル委譲

引数解釈完了後、`plugin-updater` スキルを起動して結果を待つ:

```text
Skill(skill: "plugin-updater", args: "mode=<mode> target=current-project")
```

スキルが Phase A-0〜G を実行し（Phase B / C はスキップ）、結果報告と
失敗時の対話結果をユーザに直接返す。コマンド本体は結果を加工せず透過する。

## 関連

- 全プロジェクト一括更新: [`update-all.md`](update-all.md)（`/update-all`）
- 実作業スキル: [`../skills/plugin-updater/SKILL.md`](../skills/plugin-updater/SKILL.md)
- 設計判断記録: [`../skills/plugin-updater/references/architecture-decisions.md`](../skills/plugin-updater/references/architecture-decisions.md)（ADR-PU-015: target パラメータ導入）
