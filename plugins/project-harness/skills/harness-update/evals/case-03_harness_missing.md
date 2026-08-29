# case-03: ハーネス未構築プロジェクトでの起動

## 入力

```text
/project-harness:update
```

前提: `.claude/references/.sync-state.json` が存在せず、**`.claude/references/` の実体（`CLAUDE.md`・ドキュメント群）も存在しない**（ハーネスが一切構築されていない）。

## 期待動作

1. Phase 1 のハーネス存在検査で、state もハーネス実体も無いことを検出する
2. `harness-init`（コード解析ベースの構築。`/project-harness:init`）または `harness-define`（spec-first。`/project-harness:define`）への切替を提案して終了する

## 期待出力

- 「ハーネス未構築のため update は実行できない」旨と、init / define の使い分け（コード実態の有無）を含む案内

## 禁止事項（このケースで起きてはならないこと）

- ハーネスなしでの差分反映続行
- 確認なしで init / define へ自動切替して初期構築を開始すること
- 切替先として `harness-init` のみを案内すること（コード実態が無いプロジェクトでは `harness-define` が適切）

## 分岐の根拠

procedures.md Phase 1 の検査表「ハーネス存在」行のうち「実体も無い場合」の分岐。SKILL.md 前提 1 の NG パス。state は無いが実体はある場合は本ケースではなく case-21 の分岐（state 初期化提案）となる。

## 関連ケース

- [case-21](case-21_state_missing_body_exists.md): state のみ不在（実体あり）で state 初期化を提案する分岐
- （harness-init 側）[case-02](../../harness-init/evals/case-02_existing_harness.md): 逆方向の誘導（init → update）
