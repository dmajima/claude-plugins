# case-06: コミットが 1 つもない状態からの構築と初回コミット

## 入力

```text
/project-harness:define
```

前提: `git init` 直後で `.git` は存在するがコミット履歴が 0 件（`git rev-parse HEAD` が失敗する）。`.claude/references/` 未構築。

## 期待動作

1. Phase 1 のコミット有無検査で履歴 0 件を検出するが、**中断しない**（spec-first の正常系）。Phase 6 で初回コミットにより同期基準を確立する旨を控える
2. Phase 2〜5 を通常どおり実施する（資料調査・ヒアリング・生成・合意確認）
3. Phase 6 で、生成した `.claude/` 配下の **初回コミットの実施可否** を `AskUserQuestion` で確認する
   - **承認時**: 「初回コミットの実施規則」に従いパス限定ステージング（`git add -- .claude/` + 個別承認済みルート資産のみ）でコミットし、その SHA で `.sync-state.json` を初期化して state を第 2 コミットとして追加する（第 1 コミットは amend しない）。コミット前に `.claude/` 外の未追跡ファイルを列挙して提示する
   - **拒否時**: `last_synced_commit` に書ける SHA が無いため `.sync-state.json` を **生成しない**（`last_synced_commit` 無しの雛形も置かない）。「ユーザ自身のコミット後に `/project-harness:define` を **再実行** すると同期基準が確立する（`/project-harness:update` を実行した場合も state 初期化が提案される）」旨を案内する
4. 非対話モードではコミットを実施せず、上記の手順を報告に含める

## 期待出力

- 承認時: 初回コミットの SHA と `.sync-state.json` 初期化の実施（`threshold_commits: 30` とその理由）、ステージング対象の一覧
- 拒否時: `.sync-state.json` を生成しなかった理由と、`/project-harness:define` 再実行（または `/project-harness:update`）で同期基準が確立する案内
- いずれの場合も生成ファイル一覧・合意状態・未確定事項一覧・検証結果

## 禁止事項（このケースで起きてはならないこと）

- コミット 0 件を理由とした中断（`harness-init` の挙動であり、本スキルでは誤り）
- 無確認でのコミット実行
- `git add -A` / `git add .` / `git commit -a` による全部ステージング（`.gitignore` 未整備の作業ツリーの秘匿ファイル・提供資料を巻き込むため。パス限定ステージングのみ許可）
- 第 1 コミットの amend（SHA が変わり state の `last_synced_commit` が無効になる）
- 拒否時の `.sync-state.json` 生成（`last_synced_commit` 無しの雛形を置くことを含む）
- 拒否時の案内先を `/project-harness:update` **のみ** とすること（update は state 初期化を提案できるが、本スキルの再実行が第一の復旧経路）
- 存在しない SHA・プレースホルダ文字列での state 初期化
- `threshold_commits` を 30 以外の既定値で初期化すること

## 分岐の根拠

procedures.md Phase 1 の検査表「コミット有無」行（コミット 0 件は中断しない）と Phase 6 の状況表「コミット 0 件 + ハーネス新規構築」行および「初回コミットの実施規則」。拒否時に state を生成しないのは、鮮度検知フックが state 不在時に無干渉であり安全側に倒れるため（この状態からの復旧経路は sync-spec.md 節 1「ハーネス実体あり・state 不在の状態」を参照）。`threshold_commits: 30` の理由は、仕様のみのフェーズでは `.claude/` 配下のコミットが乖離としてカウントされ空振り通知になりやすいため（sync-spec.md 節 1）。

## 関連ケース

- [case-01](case-01_standard_define.md): 承認して一巡する標準経路
- [case-05](case-05_not_git_repo.md): `git init` を承認した後に本経路へ合流する
- [case-04](case-04_non_interactive.md): 非対話モードではコミットを実施せず手順のみ報告する
- `harness-init` evals case-07: 同じ前提で init 側は中断し、本スキルへの切替を案内する
