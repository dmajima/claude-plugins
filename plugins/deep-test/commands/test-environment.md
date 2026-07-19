---
description: テスト用 Docker 派生環境を生成・起動・撤収する（テスト実行は行わない）
argument-hint: "[action=provision|up|down|status] [project=<path>]"
allowed-tools:
  - Skill
  - AskUserQuestion
---
<!-- TEST-ENVIRONMENT-COMMAND-SENTINEL-v1 -->

フェーズスキル `deep-test:test-environment`（Phase 1.7）を**単独起動**し、テスト用派生環境の生成（provision）/ 起動（up）/ 撤収（down）/ 状態確認（status）を行う。

## 起動方法

ユーザー引数をそのまま `deep-test:test-environment` スキルへ引き渡して Skill ツールで起動する。

```
Skill(skill: "deep-test:test-environment", args: "$ARGUMENTS")
```

- 本コマンドは起動とバトン渡しに徹する。target-slug 解決・docker 資産検出・`analysis.yaml` 消費・派生生成（`ports: !override` + 127.0.0.1）・`config --quiet` 検証・up / down / status・`environment.yaml` 出力・env-architect 自己チェックのロジックはスキル側が行う（本コマンドで複製しない）
- 環境マニフェスト `environment.yaml` のスキーマ・コマンド規約形・read-only 境界の SSOT は `${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` とする
- **テストの実行はしない**（up した環境の `endpoints[]` を browser 系実行スキルが受領し、`test-run-*` が実行する。SUT の既存 docker 資産へは一切書き込まない）

## 引数の解釈

| 引数 | 意味 |
|------|------|
| `action=<provision\|up\|down\|status>` | 実行する操作。`provision` = 派生生成 + マニフェスト出力（既定）/ `up` = 起動 + health 確認 / `down` = ログ保存 + 撤収 + 残存確認 / `status` = `ps` + health 再確認による状態更新 |
| `project=<path>` | SUT のプロジェクトルート（docker 資産探索の起点） |
| `target=<slug>`（別名 `target-slug=`） | データ配置先の target-slug（未指定時はスキル側の解決フロー） |
| `base=<path>` | 基準ディレクトリ（未指定時はスキル側で解決） |
| `levels=<CSV>` | 見込みテストレベル（unit のみなら環境不要 = no-op） |
| `run-id=<id>` | up / down 時のログ保存先・`status.last_run_id` に使用 |
| `--non-interactive` | 非対話モードで実行する |
| 上記以外 | 解釈せずそのままスキルに引き渡す |

## 動作モード判定

| 入力 | モード | 動作 |
|------|-------|------|
| `--non-interactive` を含む | 非対話 | 確認をスキップし `${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` の非対話既定値表で進行する（up = down までのワンサイクル完結を条件に許可・health 未達 = down して blocked 材料・target-slug 複数時 = エラー中断） |
| 含まない | 対話 | target-slug・`project=`・本番誤爆疑義の扱い・health 未達時の維持 / down などの不足情報をスキル側が確認しながら進行する |

## 使い方

```
/deep-test:test-environment                                  # 対話で派生環境を生成（provision）
/deep-test:test-environment project=./web-app                # SUT を指定して派生環境を生成
/deep-test:test-environment action=up target=orderapp-web    # provision 済み環境を起動して health 確認
/deep-test:test-environment action=down target=orderapp-web  # ログ保存 → down -v → 残存確認（中断後の片付けに有用）
/deep-test:test-environment action=status target=orderapp-web --non-interactive   # 状態のみ再確認
```

引数：`$ARGUMENTS`

## 関連コマンド

- 新規テストのフルフロー: `/deep-test:test`（Phase 1.7 provision・Phase 5 手順 0 の up・Phase 6 判定後の down として本スキルへ到達する）
- フィクスチャ基盤の単独構築: `/deep-test:test-fixture`（Phase 1.6）
- 実績 YAML からの報告書再生成: `/deep-test:test-report`
- 実施済みテストの再テスト: `/deep-test:test-retest`
