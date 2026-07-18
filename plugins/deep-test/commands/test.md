---
description: テスト設計→レビュー→実行→報告のフルライフサイクルを実行する
argument-hint: "[対象説明]"
allowed-tools:
  - Skill
  - AskUserQuestion
---

オーケストレータスキル `deep-test:test` を**フルフロー**（既定モード）で起動する。

## 起動方法

Skill ツールで起動し、ユーザー引数を**解釈せずそのまま**引き渡す。

```
Skill(skill: "deep-test:test", args: "$ARGUMENTS")
```

- 本コマンドは起動とバトン渡しに徹する。フェーズ制御・target-slug 解決・ゲート判定・実績記録のロジックはすべてオーケストレータ `test` スキルが行う（本コマンドで複製しない）
- フルフロー: setup 確認 → 解析（analyze・Phase 1.5）→ design → review（設計文脈）→ 承認ゲート → run → review（結果文脈）→ report。ゲートの定義は `${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` を SSOT とする

## 引数の解釈（オーケストレータへの引き渡し内容）

`argument-hint` は補完 UI 向けに主対象（対象説明）1 要素のみを表示する。詳細な引数（`spec=` / `levels=` / `design-only` / `run-only` / `report-only` / `--non-interactive`）は本表のとおりオーケストレータが解釈する。対話時は不足分を AskUserQuestion で確認し、明示指定もできる。

| 引数 | 意味 |
|------|------|
| `対象説明`（`key=value` 形式以外の平文） | テスト対象の説明（機能名・アプリ名・対象 URL 等の自由文）。target-slug 解決と test-design フェーズの入力になる。省略時は対話で確認する |
| `spec=<パス>` | テスト対象の仕様書パス（カンマ区切りで複数指定可）。test-design フェーズの入力になる |
| `levels=<レベルCSV>` | 対象テストレベルの限定。level 値は `${CLAUDE_PLUGIN_ROOT}/references/test-levels.md` の enum（`unit` / `functional` / `integration-internal` / `integration-external` / `system` / `uat` / `performance` / `security`）をカンマ区切りで指定する |
| `design-only` | 部分モード: 設計→設計レビューまでで完了する（run へ進まない） |
| `run-only` | 部分モード: 実行フェーズのみ。**`levels=` の指定が必須**（承認済みケースを指定レベルで絞り込んで実行する）。未指定時は対話=AskUserQuestion で確認、非対話=エラー中断 |
| `report-only` | 部分モード: 実績 YAML から報告書のみ再生成する（run なし） |
| `--non-interactive` | 非対話モードで実行する |
| 上記以外 | 解釈せずそのままオーケストレータに引き渡す |

## 動作モード判定

| 入力 | モード | 動作 |
|------|-------|------|
| `--non-interactive` を含む | 非対話 | 確認をスキップし `${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` の非対話既定値表で進行する（報告形式 = Markdown、人間承認ゲート = スキップ、target-slug 複数時 = エラー中断 等） |
| 含まない | 対話 | target-slug 選択・人間承認ゲート・報告形式選択などをオーケストレータが AskUserQuestion で確認しながら進行する |

## 使い方

```
/deep-test:test                                            # フルフロー（対象・仕様は対話で確認）
/deep-test:test 受注管理画面の検索機能                       # 対象説明を平文で渡してテスト設計から実施
/deep-test:test spec=docs/specs/order-feature.md           # 仕様書を入力にテスト設計から実施
/deep-test:test spec=docs/spec.md levels=unit,functional   # 対象レベルを限定して実施
/deep-test:test spec=docs/spec.md --non-interactive        # 非対話で一括実行
```

引数：`$ARGUMENTS`

## 関連コマンド

- 実施済みテストの再テスト（full / ng-only / ids / resume）: `/deep-test:test-retest`
- 実績 YAML からの報告書再生成: `/deep-test:test-report`
