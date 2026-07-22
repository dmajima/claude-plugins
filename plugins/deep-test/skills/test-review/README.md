# test-review スキル

deep-test プラグインのレビューフェーズを担うスキル。テスト成果物の多観点レビューという単一責務を持ち、入力によって 2 つの文脈を切り替える。

| 文脈 | 入力 | 並列起動するエージェント | 出力 |
|------|------|------------------------|------|
| 設計文脈 | test-plan.md + test-cases.yaml | coverage-reviewer / feasibility-reviewer / user-perspective-reviewer（3 並列） | 指摘統合 + PASS / NEEDS REVISION 判定。PASS 時は review_status を approved 化 |
| 結果文脈 | 実行結果サマリ + test-results.yaml + エビデンス | defect-analyst / user-perspective-reviewer（2 並列） | NG 原因分類・再現手順完全性・severity 妥当性の検証レポート（report フェーズへの引き継ぎ事項含む） |

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。
スキルが実行時に参照するのは `SKILL.md` と `references/` 配下です。

## 導入手順

本スキル `test-review` は `deep-test` プラグインに同梱されており、**追加インストールは不要**です。プラグインの導入手順（マーケットプレイス登録・インストール・自動更新の設定）は [`deep-test` プラグインの README](../../README.md) を参照してください。

- **起動トリガー**: オーケストレータ `test` の設計レビュー／結果レビュー／承認レビューからの委譲、または「テストケースをレビューして」「テスト結果をレビューして」等の自然言語依頼での単独起動

## 特徴

- 指摘には重要度（Critical / High / Medium / Low）と信頼度（0〜100）が付き、重複は統合される
- 判定基準は明文化されている: **Critical / High 指摘が 1 件以上なら NEEDS REVISION**（信頼度 40 未満は参考指摘としてカウント外）
- 設計文脈で PASS すると、レビュー対象ケースの `review_status` が `approved` になり実行対象になる（書き換えは review_status と meta.updated_at のみの最小差分）
- 結果文脈では test-results.yaml を読み取り専用で扱い、severity 補正は「提案」として report フェーズへ引き継ぐ

## 使い方

### トリガーフレーズ例

```
テストケースをレビューして
テスト計画を承認レビューして
テスト結果をレビューして
```

### 起動経路

| 経路 | 説明 |
|------|------|
| test オーケストレータ経由 | 設計後の設計レビュー / run 後の結果レビュー / 承認済みケースゲートで要求された draft 承認レビューとして委譲される |
| 単独起動 | 上記トリガーフレーズで本スキルのみを直接実行する |

### 引数

| 引数 | 内容 |
|------|------|
| `context=design` / `context=results` | 文脈の明示指定（省略時は入力パス・依頼文言から判定） |
| `target-slug=<slug>` | 対象 slug |
| `plan=` / `cases=` / `scope=` | 設計文脈: 対象ファイルとレビュー対象ケース ID |
| `results=` / `run=` | 結果文脈: 実績ファイルと対象 run_id（省略時は最新） |
| `--non-interactive` | 非対話モード（文脈判定不能時はエラー中断） |

## 動作例

### 例 1: 設計レビューで PASS

1. draft ケースを対象に 3 エージェントを並列起動
2. 指摘は Medium 2 件・Low 3 件 → 判定 PASS
3. 対象ケースの review_status を approved へ更新し、レポートを返却

### 例 2: 結果レビュー（fail 2 件）

1. 最新 run の fail 2 件の defect・エビデンスを抽出
2. defect-analyst / user-perspective-reviewer を並列起動
3. 1 件は severity 過小（medium → high 補正案）、1 件は再現手順の環境情報不足を検出
4. report フェーズへの引き継ぎ事項（補正案・エビデンス補完要否）を含むレポートを返却

## ファイル構成

```
plugins/deep-test/skills/test-review/
├── SKILL.md                          # Claude が実行時に読むスキル定義
├── README.md                         # 本ファイル（人間向け）
├── references/
│   ├── review-procedures.md          # 文脈判定・エージェント起動・統合・判定・承認処理の詳細手順
│   └── review-criteria.md            # 指摘重要度の定義・PASS / NEEDS REVISION 判定基準・統合規則
└── evals/                            # 動作分岐検証ケース（case-01〜05 + README）
```

## スコープ外

- 成果物（計画・ケース）の修正（`test-design` が担当。本スキルは差し戻し事項の提示まで）
- テストの実行・実績記録（`test-run-*` / オーケストレータ `test`）
- 報告書生成・エビデンス完全性の最終監査（`test-report`）
- ソースコードのレビュー（対象はテスト成果物のみ）

## 関連スキル

- `test` — オーケストレータ（設計レビューゲートの判定・NEEDS REVISION 時の修正ループ制御）
- `test-design` — レビュー対象（設計文脈）の生成元・差し戻し先
- `test-report` — 結果文脈の引き継ぎ事項の受け手
