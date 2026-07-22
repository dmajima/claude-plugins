# test-run-unit スキル

ユニットテスト（level: unit / TC-UNIT）をテストフレームワーク実行機構で実施する実行スキル。
プロジェクトのテストランナー（pytest / jest / vitest / dotnet test 等）を検出・実行し、出力を解析してテストケース単位の中間結果 JSON をオーケストレータへ返却する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。
スキルが実行時に参照するのは `SKILL.md` と `references/` 配下です。

## 導入手順

本スキル `test-run-unit` は `deep-test` プラグインに同梱されており、**追加インストールは不要**です。プラグインの導入手順（マーケットプレイス登録・インストール・自動更新の設定）は [`deep-test` プラグインの README](../../README.md) を参照してください。

- **起動トリガー**: オーケストレータ `test` の run フェーズから scope に unit レベルのケースが含まれる場合に自動委譲される。必須入力（target-slug／run_id／対象ケース）が揃わない直接依頼時は実行せずオーケストレータ経由を案内する

## 担当範囲

| 項目 | 内容 |
|------|------|
| テストレベル | ユニットテスト（`level: unit` / ケース ID `TC-UNIT-*`） |
| 実行機構 | テストフレームワーク実行（コードレベルの自動テスト） |
| 対応ランナー例 | pytest / jest / vitest / npm test / dotnet test / go test / mvn / gradle / cargo test |
| 実行環境 | プロジェクト既存環境を尊重（venv / node_modules 等）。導入・構築は行わない（test-setup の責務） |

## 使い方

### 起動経路

| 経路 | 説明 |
|------|------|
| オーケストレータ経由（標準） | `/deep-test:test` のフルフロー、または run-only / 再テストモードの run フェーズから、scope に unit レベルのケースが含まれる場合に自動委譲される |
| 単独起動 | 必須入力（target-slug / run_id / 対象ケース）が揃わない場合は実行せず、オーケストレータ経由の起動を案内する |

### 入出力

| 区分 | 内容 |
|------|------|
| 入力 | target-slug / run_id / 対象ケースリスト（unit レベル）/ 対象プロジェクト情報 |
| 出力 | ケースごとの中間結果 JSON（status / reason / executed_by / duration_sec / actual / evidence / defect）。**test-results.yaml への書き込みは行わない**（記録はオーケストレータが一元実行） |

## 動作例

1. オーケストレータから TC-UNIT-001〜003 の scope を受領
2. `pyproject.toml` から pytest を検出し、プロジェクトの `.venv` の python で実行
3. 出力を解析し、ケースの `data.test_pattern` と実行結果の nodeid を突合
4. 失敗テストがあればスタックトレース・再現手順・検証データを収集（defect 3 点セット + `extras.stack_trace`）
5. 実行ログを `evidence/{run_id}/{case_id}/` へ保存し、中間結果 JSON を返却

ランナーが存在しない場合は、実行を偽装せず scope 全ケースを skipped + reason で返却する。

## カスタマイズ・拡張

| 拡張対象 | 方法 |
|---------|------|
| 対応ランナーの追加 | `references/unit-execution.md` 1.2 の検出表・4.2 の解析ポイント表に行を追加する |
| マッピング規約の変更 | `references/unit-execution.md` 2 章を更新する（test-design 側のケース記載規約と整合させる） |
| 動作分岐の検証ケース追加 | `evals/` に `case-NN_<slug>.md` を追加し、`evals/README.md` の一覧表を更新する |

## ファイル構成

```
plugins/deep-test/skills/test-run-unit/
├── SKILL.md                              # Claude が実行時に読むスキル定義
├── README.md                             # 本ファイル（人間向け）
├── references/
│   └── unit-execution.md                 # ランナー別実行・出力解析・マッピング手順
└── evals/                                # 動作分岐検証ケース（case-01〜10 + README・10 ケース）
```

## スコープ外

- unit 以外のテストレベルの実行（functional / integration / system / uat / performance / security）
- test-results.yaml への書き込み・報告書生成
- テストランナー・依存パッケージの導入（test-setup が担当）
- テストケースの設計・修正、実行結果のレビュー

## 関連スキル

- `test` — オーケストレータ（run_id 採番・ゲート判定・実績記録・フェーズ制御）
- `test-setup` — テストランナー検出・実行環境の構築
- `test-run-functional` / `test-run-integration` / `test-run-scenario` / `test-run-performance` / `test-run-security` — 他レベルの実行スキル
- `test-review` — 実行結果のレビュー（結果文脈）
- `test-report` — 報告書生成
