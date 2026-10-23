---
description: ローカルの画面設計書・モックを claude.ai/design へ反映
argument-hint: "[画面ID] [--all]"
---

ユーザの引数: $ARGUMENTS

`/design-push` コマンドは、ローカル正本（`specs/` の設計書と `mocks/` のモック）を
claude.ai/design へ反映する。スクリーンショットの再生成、設計書の画面イメージ更新、
DesignSync による push、未反映記録のクリアまでを一括で行う。

Stop フックが未反映を理由に応答の終了をブロックしている状態は、このコマンド
（または `design-push` スキル）での反映によってのみ正規に解除される。

## 引数解釈

| 引数 | 解釈ルール |
|-----|----------|
| 空 | 未反映リスト（`pending.tsv`）の全件を対象にする |
| 画面 ID | その画面の設計書・モックのみを対象にする |
| `--all` | `mocksDir` 配下の全モックを対象にする |
| その他 | 自然言語として扱い、スキルへそのまま渡す |

## 前提条件

`.claude/design-bridge.json` が存在し、design-system 認可が済んでいること。
未導入の場合はスキル側が `/design-init` を案内する。

## スキル委譲

引数解釈完了後、`design-push` スキルを起動して結果を待つ:

```text
Skill(skill: "design-bridge:design-push", args: "<引数>")
```

push 計画の提示と確認はスキル側で行う。コマンド本体は結果を加工せず透過する。

## 関連

- 取り込み: [`design-pull.md`](design-pull.md)（`/design-pull`）
- 状態確認: [`design-status.md`](design-status.md)（`/design-status`）
- 実作業スキル: [`../skills/design-push/SKILL.md`](../skills/design-push/SKILL.md)
