---
description: コードレビューを簡易モード（必須トリオ impl/test/sec のみ）で実行する
argument-hint: "[scope]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - AskUserQuestion
  - Skill
  - Bash(git *)
---

`code-review` スキルを **簡易モード固定**（`mode=quick`）で起動する。

## レビュアー構成（本コマンド固有）

- 動員観点別スキル: 3種（`code-review-implementation` / `code-review-testing` / `code-review-security`）
- 各観点別スキルが内部で 1〜3 エージェントを起動する（最大 7 種：impl + linter + perf + test + runner + sec + dep）
- 動的な絞り込みは行わない（必須トリオの 3 観点別スキルは常に動員。`code-review-architecture` / `code-review-frontend` は起動しない）
- Agent Teams は採用しない（簡易モードはフォールバック条件）

## 動作・実行手順

**`${CLAUDE_PLUGIN_ROOT}/references/command-common-behavior.md` に従う。** `<MODE>` = `quick`。

## 使い方

```
/code-review-quick                                       # 現在のブランチ vs 自動判定の比較ブランチを簡易モードでレビュー
/code-review-quick PR #123                               # GitHub PR を簡易モードでレビュー（pr-review スキルにフォワード）
/code-review-quick src/Order/Order.cs                    # 特定ファイルを簡易モードでレビュー
/code-review-quick spec=docs/specs/order-feature.md      # 仕様書ベースの整合性チェック付き
```

引数：`$ARGUMENTS`

## 適用場面

- 軽微な修正・タイプミス・コメント修正
- レビュー時間 / トークン制約があるとき
- ドキュメント変更のみ
- 大規模変更のうち既に標準レビューを通過した一部変更の再確認

## モードを変更したい場合

通常のレビューや本番投入前の総合レビューは `/code-review-standard` を使用する。
