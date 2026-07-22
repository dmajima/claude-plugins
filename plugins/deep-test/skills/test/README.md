# test スキル（オーケストレータ）

`deep-test` プラグインのテストライフサイクル全体（設計 → 設計レビュー → 実行 → 結果レビュー → 報告 → 再テスト）を制御するオーケストレータ。
モード判定・target-slug 解決・フェーズ委譲・ゲート判定・実績記録（専用スクリプト経由）を担当し、テストの実務はフェーズスキル・実行スキルへ委譲する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。
スキルが実行時に参照するのは `SKILL.md` と `references/` 配下、およびプラグイン共通の `references/` です。

## 導入手順

本スキル `test` は `deep-test` プラグインに同梱されており、**追加インストールは不要**です。プラグインの導入手順（マーケットプレイス登録・インストール・自動更新の設定）は [`deep-test` プラグインの README](../../README.md) を参照してください。

- **起動トリガー**: 「このアプリをテストして」等の自然言語、または `/deep-test:test`・`/deep-test:test-retest`・`/deep-test:test-report` コマンド（テストライフサイクル全体を制御するオーケストレータ）

## 役割

| 責務 | 内容 |
|------|------|
| モード判定 | フル / 再テスト（full・ng-only・ids）/ 部分（design-only・run-only・report-only）/ resume / 非対話 |
| target-slug 解決 | `.claude/.local/plugins/deep-test/{target-slug}/` の選択・初期化 |
| フェーズ委譲 | test-setup / test-design / test-review / test-run-*（6 種）/ test-report の Skill 起動 |
| ゲート判定 | 設計レビュー / 承認済みケース / 人間承認 / MCP の 4 ゲート |
| 実績記録 | 実行スキルの中間結果を `results_manager.py` で test-results.yaml へ一元記録 |
| 再テスト対象選択 | `results_manager.py select`（対象判定マトリクス準拠の機械的抽出） |

## 使い方

### スラッシュコマンド

| コマンド | 動作 |
|---------|------|
| `/deep-test:test` | フルフロー起動（設計 → レビュー → 実行 → 結果レビュー → 報告） |
| `/deep-test:test-retest` | 再テストモード起動（full / ng-only / ids を選択） |
| `/deep-test:test-report` | report-only モード起動（実績 YAML から報告書を再生成） |

### 自然言語トリガー例

```
このアプリをテストして
テスト設計して（design-only）
NG だったケースだけ再テストして（retest ng-only）
TC-FUNC-002 と TC-SYS-001 を再テストして（retest ids）
テスト報告書を Excel で作って（report-only）
resume（再起動後の中断再開）
```

## 実行モード

| モード | 引数 | フロー |
|-------|------|-------|
| フル | （既定） | target 解決 → setup 確認 → 設計 → 設計レビュー → ゲート → 実行 → 結果レビュー → 報告 |
| 再テスト | `retest full` / `retest ng-only` / `retest ids=TC-...` | 対象抽出（select）→ ゲート → 実行 → 結果レビュー → 報告（実績はマージ） |
| 部分 | `design-only` / `run-only levels=...` / `report-only` | 該当フェーズのみ |
| 再開 | `resume` | 中断 run（in_progress / interrupted）の未実行ケースから継続（run_id を引き継ぐ） |
| 非対話 | `--non-interactive` 併用 | 確認をスキップし既定値で進行（承認ゲートスキップ・報告 Markdown 等） |

- ng-only は「NG だったケースの修正確認」専用で、回帰テストの代替ではありません（副作用検出には full を推奨）
- Playwright MCP が未ロードの場合は状態を保存して停止し、Claude Code 再起動後に `resume` で継続します

## 実績 YAML とスクリプト

テスト実績（`test-results.yaml`）の操作は同梱の `references/scripts/results/results_manager.py` に一元化されています（AI による直接編集は禁止）。

| サブコマンド | 機能 |
|------------|------|
| `init` | `{base}/{target-slug}/` の初期化 |
| `start-run` | run 開始記録（run_id 採番。stdout に run_id を出力） |
| `record` | ケース結果 1 件追記 + latest 更新（fail は defect 3 点セットの一次バリデーション） |
| `finish-run` | scope と結果の突合・欠落検出・run status 確定 |
| `select` | 再テスト対象抽出（full / ng-only / ids） |
| `validate` | 整合性チェック（fail 3 点セット・エビデンス実在・scope 突合） |
| `summary` | レベル別集計 + run 横断推移の JSON 出力 |

exit code: `0`=正常 / `1`=一般エラー / `2`=バリデーションエラー / `3`=ロック競合（`.lock` 残留時は手動削除）/ `64`=引数パースエラー。

results_manager.py の依存は PyYAML のみです。venv はセッション作業領域に、プラグイン共通の
`references/scripts/setup/setup_venv.sh`（プラグインルート直下。requirements はプラグイン単位で一元管理）で構築します。

```bash
# プラグインルート（plugins/deep-test/）からの相対パスで例示
bash references/scripts/setup/setup_venv.sh ".claude/.local/work/{session}/workspace"
".claude/.local/work/{session}/workspace/.venv/Scripts/python.exe" \
  skills/test/references/scripts/results/results_manager.py summary \
  --base ".claude/.local/plugins/deep-test" --target "my-app"
```

## ファイル構成

```
skills/test/
├── SKILL.md                        # スキル定義（Claude が読み込むエントリポイント）
├── README.md                       # 本ファイル（人間向け）
├── references/
│   ├── flow.md                     # フェーズ遷移・状態遷移図・ゲート判定手順・遡行ループ
│   ├── flow-resume.md              # resume 復帰位置判定・Phase 別実行コマンド集（flow.md から移管）
│   ├── state-handoff.md            # フェーズ間の受け渡しデータ規約（args / 返却 JSON / スクリプト入出力）
│   └── scripts/
│       └── results/
│           └── results_manager.py  # 実績 YAML 操作スクリプト（唯一の書き込み経路）
└── evals/                          # 動作分岐の検証ケース集
    ├── README.md
    └── case-01 〜 case-30（30 ケース）
```

> テストレベル定義・YAML スキーマ・再テスト規約・ゲート定義などの規範はプラグイン共通の `references/`（プラグインルート直下）にあり、全スキルで共有しています。
> venv 構築・削除スクリプト（`setup_venv.sh` / `teardown_venv.sh`）と `requirements.txt` もプラグイン共通の `references/scripts/setup/` に一元化されています。

## カスタマイズ・拡張

### 実行スキル（テストレベル）の追加

1. プラグインに `skills/test-run-<新機構>/` を追加する
2. プラグイン共通 `references/test-levels.md` のレベル → スキル対応表を更新する（本スキルはこの表を参照して委譲先を決めるため、SKILL.md の変更は不要）

### 再テスト対象判定の変更

プラグイン共通 `references/retest-policy.md` のマトリクスと `references/scripts/results/results_manager.py` の `select` 実装を**セットで**更新します（二重管理のため同期必須）。

### 実績スキーマの変更

プラグイン共通 `references/yaml-schema.md`（分割先 `yaml-schema-cases.md` / `yaml-schema-results.md` を含む）の改訂（schema_version のインクリメント）と `results_manager.py` の対応を同時に行います。

## スコープ外（本スキルが行わないこと）

- テストケースの設計・修正（test-design の責務）
- テストの実行そのもの（test-run-* の責務）
- 成果物レビュー・エージェントの直接起動（test-review 等の責務）
- 報告書の生成（test-report の責務）
- 受入（UAT）の最終判断・リリース判断（人間の責務）
