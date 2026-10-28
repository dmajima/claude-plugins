---
description: design-bridge をリポジトリへ導入し画面設計とデザインを連動させる
argument-hint: "[--non-interactive]"
---

ユーザの引数: $ARGUMENTS

`/design-init` コマンドは、現在のリポジトリに design-bridge を導入する。
ディレクトリ構成の作成、claude.ai/design の design-system プロジェクトとの紐付け、
`.claude/design-bridge.json` の生成、スクリーンショット用 venv の構築までを行う。

## 引数解釈

| 引数 | 解釈ルール |
|-----|----------|
| 空 | `mode = interactive`（対象プロジェクト・構成をユーザに確認） |
| `--non-interactive` | `mode = non-interactive`（既定値で確定して進行） |
| その他 | 自然言語として扱い、スキルへそのまま渡す |

## 前提条件

git リポジトリ配下で、かつ `/design-login` による design-system 認可が済んでいること。
前提の検証はスキル側で行う（コマンド側では事前検証しない）。

## スキル委譲

引数解釈完了後、`bridge-init` スキルを起動して結果を待つ:

```text
Skill(skill: "design-bridge:bridge-init", args: "<引数>")
```

スキルが導入処理を実行し、結果報告と対話結果をユーザに直接返す。
コマンド本体は結果を加工せず透過する。

## 関連

- 反映: [`design-push.md`](design-push.md)（`/design-push`）
- モック生成: [`design-mock.md`](design-mock.md)（`/design-mock`）
- 実作業スキル: [`../skills/bridge-init/SKILL.md`](../skills/bridge-init/SKILL.md)
