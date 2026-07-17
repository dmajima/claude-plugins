# code-review-implementation evals

本ディレクトリは `code-review-implementation` 観点別スキルの **AI の動作分岐検証ケース集**。
1 ケース 1 ファイルで、スキルの規範（SKILL.md / references/）に基づく分岐ごとに期待動作を定義する。

## ケース一覧

| case | ファイル名 | 検証する分岐 | 起動形態 |
|------|-----------|------------|---------|
| 01 | case-01_delegated_no_spec.md | 委譲・spec_summary なし・動的検証権限あり（3 エージェント並列 + 仕様整合性チェックのスキップ + EXECUTED） | 委譲 |
| 02 | case-02_spec_summary_consistency.md | spec_summary 指定あり（implementation-engineer が仕様整合性を追加観点として評価） | 委譲 |
| 03 | case-03_standalone_linter_skipped.md | 単独実行・動的検証権限なし（SKIPPED 明示 + progress.md 自スキル作成） | 単独 |
| 04 | case-04_implementation_review.md | 「実装の品質をレビューして」フレーズでの起動（トリガー検証） | 単独 |
| 05 | case-05_performance_review.md | パフォーマンス観点フレーズでの起動（トリガー検証） | 単独 |
| 06 | case-06_linter_only.md | 「Linter だけ実行して」フレーズでの起動（トリガー検証） | 単独 |
| 07 | case-07_language_profiles_applied.md | language-profiles 受領とエージェント適用（O10 前段・委譲経路） | 委譲 |
| 08 | case-08_self_detection_language.md | language-profiles 未受領の単独起動で言語・FW を自己検出しエージェントに適用（O10 自己検出・後段） | 単独 |
| 09 | case-09_regression_defensive_code.md | 差分削除側（- 行）の防御コード（例外処理・リソース解放）消失を回帰として指摘（U16） | 委譲 |
| 10 | case-10_scope_out_testing_security.md | テスト実行 / セキュリティ要求の混在時のスコープ外誘導（testing / security へ誘導 + スコープ内/外フラグ・O4/O5） | 単独 |

## ケースファイルの構成

各ケースファイルは以下のセクションで構成する。

| セクション | 内容 |
|-----------|------|
| 入力 | 委譲 args または起動フレーズ / 起動形態（委譲・単独）・前提 |
| 分岐の根拠 | SKILL.md / references のどの規範に基づく分岐か（ファイル名・セクションを明記） |
| 期待動作 | 検証可能な期待動作の箇条書き |
| 関連ケース | 対になる分岐・前提となるケースへの参照 |

## 起動形態の軸について

本スキルの evals は「委譲（オーケストレーター経由）」と「単独（ユーザー直接起動）」の 2 起動形態を主軸に分岐を検証する。この軸は対話/非対話モードの代替として機能する: 委譲時はオーケストレーターがモード・スコープ・言語プロファイルを引数で確定済みのため非対話的に進行し、単独時は本スキル自身が progress.md 作成・自己検出（O8 / O10）を行う。モード確認（AskUserQuestion）はオーケストレーター（code-review）の責務のため、観点別スキル単体の evals では扱わない。
