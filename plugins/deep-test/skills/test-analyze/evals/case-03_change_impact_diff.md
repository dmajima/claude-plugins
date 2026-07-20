# case-03 変更影響分析（diff= と change_impact・回帰スコープ提案）

`diff=` 引数で対象差分が指定されたケース。変更ファイル → 依存逆引きで影響モジュール / EP を特定し、`change_impact` に回帰スコープ候補を **提案のみ** として材料化することを検証する。回帰対象の確定・実行はしない。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=orderapp-web 対象説明=./ diff=main..feature/x base=<base>` |
| 起動形態 | 委譲（オーケストレータ `test` から Skill ツール経由） |
| 前提 | リポジトリソースは full で取得可 / `main..feature/x` に変更コミットが存在 / `spec=` 指定なし |

## 分岐の根拠

SKILL.md「前提」の引数表（`diff=` は変更影響分析の対象差分）・責務 6（変更影響分析・提案のみ）・「検証」（`diff=` 未指定時に change_impact を出力しない）、references/procedures.md 4.11 章（変更影響分析・`git diff --name-only`・依存逆引き・`suggested_regression_scope` は提案のみ）・6.1 章（`meta.diff_ref` の反映）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-analysis.md` 14 章（change_impact の changed_files / impacted_modules / impacted_entry_points / suggested_regression_scope・未指定時は非出力）・3 章（`meta.diff_ref`）。

## 期待動作

- 委譲で `target-slug=` を受領しているため slug の解決フロー・確認は行わない
- full のコードベース解析（責務 1〜12）を実施し entry_points を材料化する（change_impact の EP 参照の前提）
- Bash の read-only git 読み取り（`git diff --name-only main..feature/x` 等）で `changed_files` を取得する（SUT のプロダクションコードへ書き込まない）
- 依存逆引きで `impacted_modules` / `impacted_entry_points`（`EP-` id 参照）を算出し、`suggested_regression_scope` を **提案のみ** として記録する（回帰対象の確定・実行はしない = 決定は test-design / retest-policy.md 側）
- `meta.diff_ref: main..feature/x` を設定する
- `spec=` 未指定のため `spec_divergence` を出力しない
- 逆引きで到達可否が不明な影響は断定せず `open_questions` に記録する（捏造禁止）
- target-analysis.md に「変更影響」章を追加し、impacted EP を EP-id で参照する
- source-analyst 自己チェックを経てから返却する

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{target-slug}/analysis.yaml`（`meta.diff_ref: main..feature/x`・`change_impact` の changed_files / impacted_modules / impacted_entry_points / `suggested_regression_scope`〔提案のみ〕）・`{target-slug}/target-analysis.md`（「変更影響」章）。spec_divergence は出力しない。test-results.yaml / test-cases.yaml / test-plan.md へは書き込まない |
| 標準出力（要約） | 解析結果サマリに加え、変更影響（変更ファイル数・影響 EP 数・回帰スコープ提案）と、到達不明の open_questions |
| 終了状態 | source-analyst 自己チェック後に材料 2 ファイルを返却。回帰スコープは提案（hint）に留め、確定・実行はしない |

## 関連ケース

- case-01: `diff=` なし（change_impact を出力しない側）
- case-02: `spec=` 指定（spec_divergence 側の入力オプション分岐）
