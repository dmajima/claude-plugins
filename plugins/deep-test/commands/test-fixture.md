---
description: Playwright フィクスチャ基盤（認証/モック/シード/base）を構築・拡充する（実行は行わない）
argument-hint: "[project=<path>] [target-slug=<slug>] [--non-interactive]"
allowed-tools:
  - Skill
  - AskUserQuestion
---

フェーズスキル `deep-test:test-fixture`（Phase 1.6）を**単独起動**し、Playwright フィクスチャ基盤を構築 / 拡充する。

## 起動方法

ユーザー引数をそのまま `deep-test:test-fixture` スキルへ引き渡して Skill ツールで起動する。

```
Skill(skill: "deep-test:test-fixture", args: "$ARGUMENTS")
```

- 本コマンドは起動とバトン渡しに徹する。target-slug 解決・`analysis.yaml` 消費・既存基盤検出・生成 / 拡充・`fixtures.yaml` 出力・fixture-architect 自己チェックのロジックはスキル側が行う（本コマンドで複製しない）
- フィクスチャ基盤マニフェスト `fixtures.yaml` のスキーマ・書き込み境界の SSOT は `${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md` とする
- **テストケースの設計・実行はしない**（`fixtures.yaml` を材料に `test-design` がケースの `fixtures:` と `automation: playwright-test` を決定し、`test-run-*` が実行する）

## 引数の解釈

| 引数 | 意味 |
|------|------|
| `project=<path>` | SUT のプロジェクトルート（テストコード生成先の基準・既存 config 検出の起点） |
| `target-slug=<slug>` | データ配置先の target-slug（未指定時はスキル側の解決フロー） |
| `base=<path>` | 基準ディレクトリ（未指定時はスキル側で解決） |
| `--non-interactive` | 非対話モードで実行する |
| 上記以外 | 解釈せずそのままスキルに引き渡す |

## 動作モード判定

| 入力 | モード | 動作 |
|------|-------|------|
| `--non-interactive` を含む | 非対話 | 確認をスキップし `${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` の非対話既定値表で進行する（target-slug 複数時 = エラー中断、`.gitignore` 追記 = 提案のみ） |
| 含まない | 対話 | target-slug・`project=`・`.gitignore` 追記可否などの不足情報をスキル側が確認しながら進行する |

## 使い方

```
/deep-test:test-fixture                              # 対話でフィクスチャ基盤を構築 / 拡充
/deep-test:test-fixture project=./web-app            # SUT プロジェクトルートを指定して構築 / 拡充
/deep-test:test-fixture target-slug=orderapp-web --non-interactive   # 非対話で指定対象のフィクスチャ基盤を構築 / 拡充
```

引数：`$ARGUMENTS`

## 関連コマンド

- 新規テストのフルフロー: `/deep-test:test`（Phase 1.6 として本スキルへ到達する）
- 実績 YAML からの報告書再生成: `/deep-test:test-report`
- 実施済みテストの再テスト: `/deep-test:test-retest`
