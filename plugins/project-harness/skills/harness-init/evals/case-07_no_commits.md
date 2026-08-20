# case-07: コミットが 1 つもない git リポジトリでの起動

## 入力

```text
/project-harness:init
```

前提: `git init` 直後で `.git` は存在するがコミット履歴が 0 件（`git rev-parse HEAD` が失敗する）。

## 期待動作

1. Phase 1 のコミット有無検査で履歴 0 件を検出する
2. `.sync-state.json` の同期基準となる HEAD が存在しないため、初回コミット後の再実行を案内して中断する

## 期待出力

- コミットが必要な理由（同期基準に HEAD の SHA を使う）と再実行手順の案内

## 禁止事項（このケースで起きてはならないこと）

- コミットなしでのハーネス生成続行・`.sync-state.json` の生成（`last_synced_commit` に書ける SHA がない）
- 無確認でのコミット実行

## 分岐の根拠

procedures.md Phase 1 の検査表「コミット有無」行。case-05（`.git` 自体がない）とは異なり git リポジトリではあるため、`git init` 提案ではなく初回コミット案内となる。

## 関連ケース

- [case-05](case-05_not_git_repo.md): `.git` 自体が存在しないプロジェクト
