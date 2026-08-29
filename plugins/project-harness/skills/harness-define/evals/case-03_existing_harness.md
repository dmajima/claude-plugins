# case-03: 構築済みハーネスへの仕様追加（ドキュメント追加モード）

## 入力

```text
新機能の仕様を先行作成して
```

前提: `.claude/references/.sync-state.json` が存在する構築済みハーネス。未実装機能の要件・仕様を先行して追加したい。

## 期待動作

1. Phase 1 の既存ハーネス検査で `.claude/references/.sync-state.json` の存在を検出し、**ドキュメント追加モード** で続行する（中断も再構築確認も行わない）
2. 骨格生成（structure-spec.md 節 10）と `.sync-state.json` の初期化を **スキップ** する
3. `requirements/` が未作成の場合は、任意構成（structure-spec.md 節 2.1）として後から追加できる
4. Phase 3〜4 で追加分のみを生成する。追加ドキュメントには `status: draft`・`sources: []`・合意ベースの定型注記・出典を設定する。既存ドキュメントの記載は無確認で変更しない（変更が必要な場合は個別に `AskUserQuestion` で確認する）
5. 追加が発生したフォルダの `CLAUDE.md` 索引と `.claude/CLAUDE.md` をメインが更新し、ファイル実体と一致させる（authoring-spec.md 節 5）
6. Phase 5 の合意確認は通常どおり実施し、承認分を `agreed` へ遷移させる
7. Phase 6 では `.sync-state.json` の `last_synced_commit` / `initialized_at` を **変更しない**（次回 `harness-update` が `.claude/` 配下の変更として整合確認する）。ただし現行版より下位のハーネスへ任意要素（`status` / `requirements/`）を導入した場合に限り、`harness_spec_version` のみを現行版へ更新する（宣言版と実体構成の整合維持。state の再初期化とは別操作であり、同期基準は保持される）

## 期待出力

- 追加ファイル一覧（フォルダ別件数）と更新した索引
- 合意状態（`agreed` N 件 / `draft` M 件）・未確定事項一覧・検証スクリプトの結果
- 「ドキュメント追加モードで実行し `.sync-state.json` は変更していない」旨

## 禁止事項（このケースで起きてはならないこと）

- 既存ハーネスの再構築・既存ドキュメントの無確認上書き
- `.sync-state.json` の再初期化（`last_synced_commit` が巻き戻り差分検出が壊れる。任意要素導入時の `harness_spec_version` のみの更新は再初期化に当たらず、実施してよい）
- 追加したフォルダの `CLAUDE.md` 索引・`.claude/CLAUDE.md` の更新漏れ（実体と索引の不一致）
- 既存 `implemented` ドキュメントの `status` を無確認で差し戻すこと
- 追加ドキュメントに既存実装のパスを `sources` として推測で紐付けること（紐付けは `harness-update` の実装追随の責務）

## 分岐の根拠

procedures.md Phase 1 の検査表「既存ハーネス」行（ドキュメント追加モードで続行）と Phase 6 の状況表「既存ハーネスあり（ドキュメント追加モード）」行。SKILL.md の 2 軸判定でも「コード実態なし・僅少 かつ ハーネスあり」「コード実態あり かつ 未実装機能の仕様を先行作成したい」は本スキルの担当。

## 関連ケース

- [case-01](case-01_standard_define.md): ハーネス未構築で骨格から生成する標準フロー
- [case-07](case-07_code_exists_switch.md): コード実態がある状態で本スキルを起動した場合のスキル選択確認
- [case-09](case-09_agreement_revision.md): 追加分の合意確認で修正指示が出た場合
