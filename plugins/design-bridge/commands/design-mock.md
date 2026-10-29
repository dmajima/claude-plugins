---
description: 画面設計書とトンマナから画面モック HTML を生成
argument-hint: "[画面ID] [--tokens] [--layout]"
---

ユーザの引数: $ARGUMENTS

`/design-mock` コマンドは、Markdown の画面設計書とトンマナ・基礎レイアウトから
画面モック HTML を生成する。生成した HTML には Design System ペインのカード索引に
必要な `@dsCard` マーカーが付与される。

## 引数解釈

| 引数 | 解釈ルール |
|-----|----------|
| 空 | 対象画面をユーザに確認する |
| 画面 ID | その画面のモックを生成する |
| `--tokens` | トンマナ（`_tokens.html`）の雛形を生成する |
| `--layout` | 基礎レイアウト（`_layout.html`）の雛形を生成する |
| その他 | 自然言語として扱い、スキルへそのまま渡す |

## 前提条件

`.claude/design-bridge.json` が存在すること。画面モックの生成には、対象画面の
Markdown 設計書が `specsDir` にあることが必要（トンマナ・レイアウト生成時は不要）。

## スキル委譲

引数解釈完了後、`bridge-mock` スキルを起動して結果を待つ:

```text
Skill(skill: "design-bridge:bridge-mock", args: "<引数>")
```

既存ファイルの上書き確認はスキル側で行う。コマンド本体は結果を加工せず透過する。

## 関連

- 反映: [`design-push.md`](design-push.md)（`/design-push`）
- 導入: [`design-init.md`](design-init.md)（`/design-init`）
- 実作業スキル: [`../skills/bridge-mock/SKILL.md`](../skills/bridge-mock/SKILL.md)
