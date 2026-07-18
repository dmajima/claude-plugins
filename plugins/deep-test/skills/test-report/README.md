# test-report スキル

テスト実績 YAML（`test-results.yaml` / `test-cases.yaml`）から、**Excel または Markdown のテスト報告書 1 ファイル**を生成する報告スキル。
生成前に results_manager.py の validate と evidence-auditor エージェントによる**エビデンス完全性の最終バリデーション**を行い、
fail の defect 3 点セット欠落・scope/results 不整合・未マスクの機微情報を検出した場合は生成せずに差し戻す。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。
スキルが実行時に参照するのは `SKILL.md` と `references/` 配下、およびプラグイン共通 `references/`（`report-format.md` 等）です。

## 使い方

### トリガーフレーズ例

```
テスト報告書を作成して
テスト結果を Excel にまとめて
実績から報告書を再生成して
```

### 起動経路

| 経路 | 説明 |
|------|------|
| オーケストレータ `test` 経由 | フルフロー / 再テストの report フェーズ、または `/deep-test:test-report`（report-only モード）から Skill ツールで委譲される |
| 単独起動 | 上記トリガーフレーズで本スキルのみを直接実行する（target-slug 解決から実施） |

### 形式選択

- 対話時: AskUserQuestion で Excel / Markdown を選択
- 非対話時（`--non-interactive`）: Markdown 既定

## 報告書サンプル構成

フォーマットの正（SSOT）はプラグイン共通 `references/report-format.md`。概要のみ示す。

### Excel（1 ファイル・シート分け）

| シート | 内容 |
|-------|------|
| サマリ | 基本情報（エビデンスパス基準注記付き）・run 情報・レベル別集計（latest 採用）・NG 一覧・未確認事項（skipped + ケース定義に存在しない実績 ID）・総合判定（PASS/FAIL/INCOMPLETE）・免責注記 5 項目 |
| 推移 | run 集計推移（fail 数の推移等）+ ケース別 status 推移マトリクス |
| レベル別シート | 実施レベルのみ作成（ユニット / 単体 / 内部結合 / 外部結合 / システム / 受入(UAT) / 性能 / セキュリティ）。ケース明細 12 列 + NG 詳細 |

status セルは条件付き書式（pass=緑 / fail=赤 / blocked=橙 / skipped=灰 / na=薄灰）、ヘッダは濃紺 #1F3864・白字、
ウィンドウ枠固定（レベル別シートは B2）、A4 横・タイトル行リピート印刷を適用済み。

### Markdown（1 ファイル・6 章）

1. サマリ → 2. 推移 → 3. レベル別結果 → 4. NG 詳細（再現手順・検証データ・severity・エビデンスパス）→ 5. 未確認事項 → 6. 免責注記

エビデンス参照は Excel と対称なコード span のパス文字列表記です（テスト実績データディレクトリ基準の相対パスであり、報告書からの相対リンクではありません。サマリに基準注記を出力します）。

### 出力ファイル名

```
test-report_{target-slug}_{yyyyMMdd}.xlsx
test-report_{target-slug}_{yyyyMMdd}.md
```

出力先はセッション作業領域直下（`.claude/.local/work/{session}/`）。

## 動作例

```
入力: 「sample-web-app のテスト報告書を作成して」（対話・Excel 選択）
出力: .claude/.local/work/20260717_01_test_report/test-report_sample-web-app_20260717.xlsx
      シート: サマリ, 推移, ユニット, 単体, 外部結合, システム, 性能
      総合判定: FAIL / NG 件数: 1 / 未確認事項: 1
```

fail に defect 3 点セット欠落がある場合は報告書を生成せず、違反一覧（ケース ID・欠落項目）を返して差し戻す。

## カスタマイズ・拡張

| 変更したい内容 | 変更先 |
|---------------|--------|
| シート構成・列定義・スタイル・免責注記 | プラグイン共通 `references/report-format.md`（SSOT）を改訂したうえで `references/scripts/report/` の実装を同期（集計・共通定数は `report_model.py`、形式固有の出力は `generate_excel.py` / `generate_markdown.py`） |
| 依存パッケージのバージョン | プラグイン共通 `references/scripts/setup/requirements.txt`（プラグインルート直下。更新時は両スクリプトの動作確認必須） |
| 実行手順・トラブルシュート | `references/procedures.md` |

## ファイル構成

```
plugins/deep-test/skills/test-report/
├── SKILL.md                          # Claude が実行時に読むスキル定義
├── README.md                         # 本ファイル（人間向け）
├── references/
│   ├── setup.md                      # venv 構築・依存パッケージ・削除手順
│   ├── procedures.md                 # 生成スクリプト実行手順・実測記録・トラブルシュート
│   └── scripts/
│       └── report/                   # 報告書生成
│           ├── report_model.py       # 共通データモデル（読み込み・集計・共通定数の一元化）
│           ├── generate_excel.py     # Excel 報告書生成（openpyxl 全コード生成方式）
│           └── generate_markdown.py  # Markdown 報告書生成（GFM・6 章構成）
└── evals/                            # 動作分岐検証ケース（case-01〜05 + README）
```

> venv 構築・削除スクリプト（`setup_venv.sh` / `teardown_venv.sh`）と `requirements.txt`（PyYAML / openpyxl・バージョン固定）は
> プラグイン共通の `references/scripts/setup/`（プラグインルート直下）に一元化されています。

## スコープ外

- テストの実行（`test-run-*` スキルが担当）
- 実績 YAML（test-results.yaml）への書き込み（オーケストレータ `test` が results_manager.py 経由で一元実行）
- 欠陥修正・再テストの起動
- リリース可否・受入可否の判断（総合判定は機械的集計であり、判断は人間が行う）

## 関連スキル

- `test` — オーケストレータ（report フェーズから本スキルへ委譲・実績記録の一元管理）
- `test-run-unit` / `test-run-functional` / `test-run-integration` / `test-run-scenario` / `test-run-performance` / `test-run-security` — 実績を生む実行スキル
- `test-review` — 結果レビュー（severity 妥当性・欠陥分析。報告の前段）
