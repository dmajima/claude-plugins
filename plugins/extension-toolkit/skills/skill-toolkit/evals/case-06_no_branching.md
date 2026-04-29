# Case 06: 動作分岐なしスキル（evals 省略）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "単純な手順スキル `daily-summary` を作って（分岐なし）" |
| 引数 | `daily-summary --no-branching` |
| フラグ | `--no-branching` |
| 既存状態 | 未存在 |

## 期待動作

### Phase 1: パラメータ確認

通常確認、ただし「動作分岐の有無」は `--no-branching` フラグで false 確定。

### Phase 2: テンプレート展開

`templates/skill/` から `evals/` 関連ファイルをコピーしない。

### Phase 3: 検証

- `evals/` ディレクトリが存在しないこと
- `SKILL.md` に動作分岐表が含まれないこと（実行モード判定の節は維持）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | 通常一式から `evals/` を除外 |
| 標準出力（要約） | 「`daily-summary` スキル作成（動作分岐なし、evals 省略）」 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは `--no-branching` フラグの有無 である。

## 注意

「動作分岐なし」と判定するのは慎重に行うこと。判定基準は [`../../../references/eval-guide.md`](../../../references/eval-guide.md) の「evals が必須となる条件」を参照。条件に該当する場合は `--no-branching` フラグでもユーザに警告する。

## 関連ケース

- `case-01_new_skill_interactive.md`（通常、evals あり）
