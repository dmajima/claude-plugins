---
description: コードレビューを標準モード（最大10種エージェント動員・差分内容により一部省略）で実行する
argument-hint: "[scope]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - AskUserQuestion
  - Skill
  - Bash(git *)
---

`code-review` スキルを **標準モード固定**（`mode=standard`）で起動する。

## レビュアー構成（本コマンド固有）

- 動員観点別スキル: 5種（`code-review-implementation` / `code-review-testing` / `code-review-security` / `code-review-architecture` / `code-review-frontend`）
- 各観点別スキルが内部で 1〜3 エージェント（合計 10 種のエージェント）を並列起動する
- architecture / frontend は差分内容に該当しない場合のみオーケストレーターが省略
- Agent Teams を採用する場合がある（大規模変更・セキュリティクリティカル変更時等）

## 動作・実行手順

**`${CLAUDE_PLUGIN_ROOT}/references/command-common-behavior.md` に従う。** `<MODE>` = `standard`。

## 使い方

```
/code-review-standard                                          # 現在のブランチ vs 自動判定の比較ブランチを標準モードでレビュー
/code-review-standard PR #123                                  # GitHub PR を標準モードでレビュー（pr-review スキルにフォワード）
/code-review-standard src/Order/Order.cs                       # 特定ファイルを標準モードでレビュー
/code-review-standard spec=docs/specs/order-feature.md         # 仕様書ベースの整合性チェック付き
/code-review-standard spec=docs/req-001.md,docs/api-spec.md    # 複数の仕様書指定
```

引数：`$ARGUMENTS`

## モードを変更したい場合

軽微な変更や時間制約があるレビューは `/code-review-quick` を使用する。
