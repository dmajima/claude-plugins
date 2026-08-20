# case-03: ハーネス未構築プロジェクトでの起動

## 入力

```text
/project-harness:update
```

前提: `.claude/references/.sync-state.json` が存在しない。

## 期待動作

1. Phase 1 のハーネス存在検査で未構築を検出する
2. `harness-init`（`/project-harness:init`）への切替を提案して終了する

## 期待出力

- 「ハーネス未構築のため update は実行できない」旨と init への案内

## 禁止事項（このケースで起きてはならないこと）

- ハーネスなしでの差分反映続行
- 確認なしで init へ自動切替して初期構築を開始すること

## 分岐の根拠

procedures.md Phase 1 の検査表「ハーネス存在」行。SKILL.md 前提 1（`.sync-state.json` の存在）の NG パス。

## 関連ケース

- （harness-init 側）[case-02](../../harness-init/evals/case-02_existing_harness.md): 逆方向の誘導（init → update）
