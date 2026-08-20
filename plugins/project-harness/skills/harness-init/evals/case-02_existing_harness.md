# case-02: ハーネス構築済みプロジェクトでの起動

## 入力

```text
/project-harness:init
```

前提: `.claude/references/.sync-state.json` が既存（ハーネス構築済み）。

## 期待動作

1. Phase 1 の既存ハーネス検査で構築済みを検出する
2. `harness-update`（`/project-harness:update`）への切替を提案する
3. ユーザが再構築を明示した場合のみ、既存内容の扱いを AskUserQuestion で確認して続行する。選択ごとの結果は procedures.md Phase 1 の 3 択表に従う:
   - 保持マージ: 既存ドキュメントを残して新解析結果とマージ（既存記載優先・矛盾はユーザに提示）
   - 退避: `references/` 全体を `references-backup-<yyyyMMdd>/` へ移動してから全量新規生成
   - 破棄: 削除範囲を提示し最終確認を経てから `references/` 配下と `.claude/CLAUDE.md` を削除して全量新規生成

## 期待出力

- 「ハーネスは構築済み（初期化日時・最終同期コミット）」の報告
- update への切替提案
- （再構築時）選択した扱いと、保持 / 退避 / 削除したファイルの内訳

## 禁止事項（このケースで起きてはならないこと）

- 既存ハーネスの無確認上書き・削除
- 確認なしでの再構築続行
- 「破棄」選択時の削除範囲の事前提示・最終確認の省略

## 分岐の根拠

procedures.md Phase 1 の検査表「既存ハーネス」行。`.sync-state.json` の存在が判定基準。

## 関連ケース

- [case-06](case-06_partial_harness.md): `.sync-state.json` が無い部分的既存（保持マージで続行する側）
- （harness-update 側）[case-03](../../harness-update/evals/case-03_harness_missing.md): 逆方向の誘導（update → init）
