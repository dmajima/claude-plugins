---
description: オーケストレータ deep-test:test を再テストモードで起動する
argument-hint: "[full | ng-only | ids=TC-... | resume] [--non-interactive]"
allowed-tools:
  - Skill
  - AskUserQuestion
---

オーケストレータスキル `deep-test:test` を**再テストモード**で起動する。

## 起動方法

引数からモードを特定し、下表の「引き渡す引数」に変換して Skill ツールで起動する。モード以外の引数（`--non-interactive` 等）はそのまま後ろに付けて引き渡す。

```
Skill(skill: "deep-test:test", args: "<引き渡す引数>")
```

- 本コマンドはモード引数の特定とバトン渡しに徹する。対象抽出（select）・承認済みケースゲート・MCP ゲート・実行・実績マージのロジックはすべてオーケストレータが行う（本コマンドで複製しない）
- 対象判定マトリクス・latest 集計規則・resume の規約は `${CLAUDE_PLUGIN_ROOT}/references/retest-policy.md` を SSOT とする

## 引数の解釈

| 指定 | 引き渡す引数 | 意味 |
|------|-------------|------|
| `full` | `retest full` | 承認済み全ケースの再テスト（修正の副作用検出に推奨） |
| `ng-only` | `retest ng-only` | 最新 status が fail / blocked / skipped のケースと未実行ケースの再テスト |
| `ids=TC-...` | `retest ids=TC-...` | カンマ区切りで指定した case_id のみ再テスト（例: `ids=TC-FUNC-002,TC-SYS-001`） |
| `resume` | `resume` | 中断 run（in_progress / interrupted）の未実行ケースから継続する（新規 run を作らない） |
| `--non-interactive` | そのまま付与 | 非対話モードで実行する |
| 上記以外 | そのまま付与 | 解釈せずオーケストレータに引き渡す |

> 注意: **ng-only は回帰テストの代替ではない**（`${CLAUDE_PLUGIN_ROOT}/references/retest-policy.md`）。修正が pass 済みケースへ与える副作用の検出には full を推奨する。

## モード未指定時の動作

| 動作モード | 動作 |
|-----------|------|
| 対話 | AskUserQuestion で 4 モード（full / ng-only / ids / resume）から選択させる。各選択肢には上表の意味を 1 行で添える。`ids` 選択時はコマンド層では実績を照会せず、`retest ids` としてオーケストレータ（`deep-test:test`）へ委譲する。オーケストレータが `summary` の `latest_fails` から直近 NG ケースの選択肢を提示（AskUserQuestion・複数選択可）して対象 case_id を確定し、取得不能時（`latest_fails` が取得できない・空・一覧外の ID を指定したい場合）は自由入力（カンマ区切り）にフォールバックする |
| 非対話（`--non-interactive`） | エラーとして中断する（モードを自動選択しない）。モードの指定方法（`full` / `ng-only` / `ids=TC-...` / `resume`）を案内する |

## 動作モード判定

| 入力 | モード | 動作 |
|------|-------|------|
| `--non-interactive` を含む | 非対話 | 確認をスキップし `${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` の非対話既定値表で進行する |
| 含まない | 対話 | 不足情報（モード・対象 case_id 等）を AskUserQuestion で確認する |

## 使い方

```
/deep-test:test-retest                                   # モードを対話で選択して再テスト
/deep-test:test-retest full                              # 全体再テスト（回帰確認）
/deep-test:test-retest ng-only                           # NG（fail / blocked / skipped）のみ再テスト
/deep-test:test-retest ids=TC-FUNC-002,TC-SYS-001        # 指定ケースのみ再テスト
/deep-test:test-retest resume                            # 中断した run を継続
/deep-test:test-retest ng-only --non-interactive         # 非対話で NG のみ再テスト
```

引数：`$ARGUMENTS`

## 関連コマンド

- 新規テストのフルフロー: `/deep-test:test`
- 実績 YAML からの報告書再生成: `/deep-test:test-report`
