---
description: 実績 YAML からテスト報告書のみ再生成する（実行は行わない）
argument-hint: "[--non-interactive]"
allowed-tools:
  - Skill
  - AskUserQuestion
---

オーケストレータスキル `deep-test:test` を **report-only モード**で起動する。

## 起動方法

モード引数 `report-only` を先頭に付け、ユーザー引数をそのまま後ろに付けて Skill ツールで起動する。

```
Skill(skill: "deep-test:test", args: "report-only $ARGUMENTS")
```

- 本コマンドは起動とバトン渡しに徹する。target-slug 解決・最終バリデーション（validate）・報告書生成のロジックはオーケストレータと test-report フェーズが行う（本コマンドで複製しない）
- 実績 YAML が SSOT のため、報告書はテスト実行なしで何度でも再生成できる。フォーマット・集計規則（latest 採用）の SSOT は `${CLAUDE_PLUGIN_ROOT}/references/report-format.md` とする

## 引数の解釈

| 引数 | 意味 |
|------|------|
| `--non-interactive` | 非対話モードで実行する |
| 上記以外 | 解釈せずそのままオーケストレータに引き渡す |

## 報告形式の選択（フロー内で実施）

形式選択は本コマンドでは行わず、フロー内の規約に従う。

| 動作モード | 形式 |
|-----------|------|
| 対話 | AskUserQuestion で Excel / Markdown を選択する（`${CLAUDE_PLUGIN_ROOT}/references/report-format.md`） |
| 非対話 | **Markdown 既定**（`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` の非対話既定値表） |

## 動作モード判定

| 入力 | モード | 動作 |
|------|-------|------|
| `--non-interactive` を含む | 非対話 | 確認をスキップし非対話既定値表で進行する（形式 = Markdown、報告対象 = 最新 run〔集計は latest 規則で run 横断〕、target-slug 複数時 = エラー中断） |
| 含まない | 対話 | target-slug・報告形式を AskUserQuestion で確認しながら進行する |

## 使い方

```
/deep-test:test-report                       # 対話で形式（Excel / Markdown）を選択して報告書を再生成
/deep-test:test-report --non-interactive     # 非対話（Markdown 既定）で報告書を再生成
```

引数：`$ARGUMENTS`

## 関連コマンド

- 新規テストのフルフロー: `/deep-test:test`
- 実施済みテストの再テスト（full / ng-only / ids / resume）: `/deep-test:test-retest`
