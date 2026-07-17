# code-review-security evals

本ディレクトリは `code-review-security` 観点別スキルの **AI の動作分岐検証ケース集**。
1 ケース 1 ファイルで、スキルの規範（SKILL.md / references/）に基づく分岐ごとに期待動作を定義する。

## ケース一覧

| case | ファイル名 | 検証する分岐 | 起動形態 |
|------|-----------|------------|---------|
| 01 | case-01_dependency_scan_executed.md | 依存定義差分あり・スキャン権限あり（dependency-safety が脆弱性スキャン実行・EXECUTED） | 委譲 |
| 02 | case-02_dependency_scan_skipped.md | スキャン権限なし（動的検証 SKIPPED + 理由併記・静的評価は継続） | 委譲 |
| 03 | case-03_credential_masking.md | レビュー対象に認証情報パターンが含まれる（中間レポートでの伏字化） | 委譲 |
| 04 | case-04_security_review.md | セキュリティレビューフレーズでの起動（トリガー検証） | 単独 |
| 05 | case-05_dependency_vulnerability.md | 依存脆弱性確認フレーズでの起動（トリガー検証） | 単独 |
| 06 | case-06_language_profiles_applied.md | language-profiles 受領とセキュリティ観点適用（O10） | 委譲 |
| 07 | case-07_scope_out_penetration_test.md | スコープ外誘導（DAST / ペネトレ依頼・O4） | 単独 |
| 08 | case-08_self_detected_profiles.md | language-profiles 未受領時の自己検出（O10・Python+Django） | 単独 |
| 09 | case-09_severity_confidence_dedup.md | 重要度付与・重複統合（U11）+ 信頼度付与・足切り境界（U15） | 委譲 |
| 10 | case-10_regression_authorization_deletion.md | U16 回帰検出（認可チェック / 入力検証削除・削除側の防御消失を回帰指摘） | 委譲 |

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
