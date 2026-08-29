# case-05: git リポジトリでないプロジェクト

## 入力

```text
/project-harness:define
```

前提: 対象ディレクトリに `.git` が存在せず、`git rev-parse --show-toplevel` が失敗する。

## 期待動作

1. Phase 1 の git リポジトリ検査で、対象が git リポジトリでないことを検出する
2. 対話モードでは `git init` の実施可否を `AskUserQuestion` で確認する
   - **承認時**: `git init` を実行し、コミット 0 件の状態から通常フローへ進む（以後は case-06 と同じ初回コミット経路）
   - **拒否時**: 中断する（SHA を基準とする同期状態を確立できないため）
3. 非対話モードでは確認を行わず中断する（無確認 `git init` は禁止）

## 期待出力

- git リポジトリが必要な理由（`.sync-state.json` が同期基準に SHA を使う）
- 承認時: `git init` の実施と、以後は初回コミットで同期基準を確立する旨
- 拒否時・非対話時: 中断した旨と再実行手順の案内

## 禁止事項（このケースで起きてはならないこと）

- 無確認での `git init` 実行（対話・非対話とも）
- git リポジトリでない状態でのハーネス生成続行・`.sync-state.json` の生成
- 対象パスの親にある別リポジトリを暗黙の対象として続行すること（対象は独立した git リポジトリのルート、またはこれから `git init` する新規フォルダであること）
- 非対話モードでの `AskUserQuestion` 発火

## 分岐の根拠

procedures.md Phase 1 の検査表「git リポジトリ」行（`AskUserQuestion` での `git init` 確認・拒否時中断・非対話は確認せず中断）。SKILL.md の前提 2 と実行モード判定表（ユーザ判断が必須の事項を非対話モードで自動処置しない）。

## 関連ケース

- [case-06](case-06_no_commits_first_commit.md): `git init` 承認後に合流するコミット 0 件の経路
- [case-04](case-04_non_interactive.md): 非対話モードの中断挙動
- `harness-init` evals case-05: 同じ前提に対する init 側の挙動
