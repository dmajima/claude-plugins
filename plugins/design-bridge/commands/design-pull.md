---
description: claude.ai/design の変更をローカルのモックへ取り込み
argument-hint: "[パス]"
---

ユーザの引数: $ARGUMENTS

`/design-pull` コマンドは、claude.ai/design 側で加えられた変更をローカルへ取り込む。

design-bridge は **ローカル正本** を原則とするため、これは例外操作である。
このコマンドの実行自体がユーザの明示的な取り込み指示にあたる。

## 引数解釈

| 引数 | 解釈ルール |
|-----|----------|
| 空 | リモートと全件照合し、差分を提示して取り込み対象を確認する |
| パス | 該当ファイルのみを対象にする（差分提示は省略しない） |
| その他 | 自然言語として扱い、スキルへそのまま渡す |

## 前提条件

`.claude/design-bridge.json` が存在し、design-system 認可が済んでいること。
`mocksDir` 配下に未コミットの変更がある場合は、スキルが上書きで失われる旨を警告し、
続行可否をユーザーに確認する。検証はいずれもスキル側で行う。

## スキル委譲

引数解釈完了後、`bridge-pull` スキルを起動して結果を待つ:

```text
Skill(skill: "design-bridge:bridge-pull", args: "<引数>")
```

差分提示と承認はスキル側で行う。引数指定の有無にかかわらず、
上書き前の承認は省略されない。

## 関連

- 反映: [`design-push.md`](design-push.md)（`/design-push`）
- 変更せず差分だけ見る: [`design-status.md`](design-status.md)（`/design-status`）
- 実作業スキル: [`../skills/bridge-pull/SKILL.md`](../skills/bridge-pull/SKILL.md)
