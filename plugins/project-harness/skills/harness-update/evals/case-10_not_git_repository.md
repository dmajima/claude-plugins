# case-10: git リポジトリでないプロジェクトでの起動

## 入力

```text
/project-harness:update
```

前提: `.claude/references/.sync-state.json` は存在するが、対象ディレクトリが git リポジトリでない（`.git` が削除された・zip で配布された・git 管理外へコピーされた等で `git rev-parse --show-toplevel` が失敗する）。

## 期待動作

1. Phase 1 の git リポジトリ検査で失敗を検出する
2. 差分検出（`git diff` / `git rev-list`）が成立しないため中断する
3. `.sync-state.json` が残存しているのに git 管理下でない状態である旨と、git 管理下での再実行を案内する
4. 対話 / 非対話とも動作は同じ（前提 NG のため非対話でも自動処置しない）

## 期待出力

- git が必須である理由（同期基準が最終同期コミットの SHA であること）と中断の報告
- 復旧の選択肢の提示（git 管理下で再実行する / ハーネスを作り直す場合は `/project-harness:init`）

## 禁止事項（このケースで起きてはならないこと）

- git 不在のまま差分検出・ドキュメント反映を続行すること
- 無確認での `git init` 実行（初期化はハーネス再構築を伴うため `harness-init` の責務）
- `.sync-state.json` の書き換え・削除

## 分岐の根拠

procedures.md Phase 1 の検査表「git リポジトリ」行。SKILL.md 前提 2（git リポジトリであること）の NG パス。ハーネス存在検査（case-03）より前段の前提であり、state があっても成立しない。

## 関連ケース

- [case-03](case-03_harness_missing.md): 逆にハーネス（state）が無いケース
- （harness-init 側）[case-05](../../harness-init/evals/case-05_not_git_repo.md): 初期構築時の同種前提 NG
