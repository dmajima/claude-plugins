# case-11: 部分的に構築済みのハーネスへの骨格補完

## 入力

```text
/project-harness:define
```

前提: `.claude/CLAUDE.md` と `references/specs/` の一部ドキュメントは存在するが、`.claude/references/.sync-state.json` が無い（過去に手動または他ツールで部分的に作られた、あるいは本スキルの初回コミット拒否経路で state 未生成のまま中断された状態）。

## 期待動作

1. Phase 1 の既存ハーネス検査で `.sync-state.json` 不在を確認し、部分的既存検査で `.claude/CLAUDE.md` / `references/` の一部が存在することを検出する
2. 既存部分は **保持** し、不足分（不足フォルダ・不足索引・`requirements/` 等）のみを生成する（structure-spec.md 節 10 の部分的既存規定）
3. 既存ファイルの上書きが必要な場合は、個別に `AskUserQuestion` で確認する（無確認上書きをしない）
4. Phase 6 は通常どおり動作する（コミットありなら HEAD で `.sync-state.json` を初期化。`threshold_commits: 30`）
5. 非対話モードでは既存ファイルの上書きを行わず既存を保持し、マージできなかった差分を報告に列挙する

## 期待出力

- 既存として保持した部分と新規生成した部分の区別が付く生成ファイル一覧
- state 初期化の実施結果（同期基準の SHA）

## 禁止事項（このケースで起きてはならないこと）

- 既存ドキュメント・既存 `.claude/CLAUDE.md` の無確認上書き・削除
- 既存部分があることを理由とした中断（部分的既存は補完して続行する）
- `harness-update` への切替提案（本スキルが既に骨格補完を進めている文脈でスキルを往復させない。本スキルが不足分を補完して state を確立するのが正。なお update 側にも「実体あり・state 不在」から state 初期化を提案する経路自体は存在する — sync-spec.md 節 1 の復旧経路 (b)）

## 分岐の根拠

procedures.md Phase 1 の検査表「部分的既存」行と structure-spec.md 節 10（部分的既存の場合、既存部分は保持して不足分のみ生成する）。初回コミット拒否経路（case-06 拒否時）からの復旧経路のひとつでもある（sync-spec.md 節 1「ハーネス実体あり・state 不在の状態」）。

## 関連ケース

- [case-03](case-03_existing_harness.md): `.sync-state.json` が完備された構築済みハーネス（ドキュメント追加モード）
- [case-06](case-06_no_commits_first_commit.md): 初回コミット拒否により state 未生成で終了する経路（本ケースの前提を作る）
- `harness-init` evals case-06: 姉妹スキルにおける同一分岐（部分的既存）
