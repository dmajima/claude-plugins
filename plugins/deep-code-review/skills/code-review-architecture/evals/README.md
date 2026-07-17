# code-review-architecture evals

本ディレクトリは `code-review-architecture` 観点別スキルの **AI の動作分岐検証ケース集**。
1 ケース 1 ファイルで、スキルの規範（SKILL.md / references/）に基づく分岐ごとに期待動作を定義する。

## ケース一覧

| case | ファイル名 | 検証する分岐 | 起動形態 |
|------|-----------|------------|---------|
| 01 | case-01_db_change_dba_invoked.md | DB 変更あり（architect + dba を並列起動・dba セクション必須） | 委譲 |
| 02 | case-02_no_db_change_dba_omitted.md | DB 変更なし（dba を内部省略・省略理由を明記・architect は常に起動） | 委譲 |
| 03 | case-03_standalone_progress_md.md | 単独起動（progress.md を自スキルで作成・維持 + 委譲時と同一のレポート構造） | 単独 |
| 04 | case-04_architecture_review.md | アーキテクチャレビューフレーズでの起動（トリガー検証） | 単独 |
| 05 | case-05_db_schema_review.md | DB スキーマレビューフレーズでの起動（トリガー検証） | 単独 |
| 06 | case-06_language_profiles_applied.md | language-profiles 受領と FW 構造観点適用（O10 前段・委譲経路） | 委譲 |
| 07 | case-07_scope_out_guidance.md | スコープ外誘導（実装/テスト/セキュリティ混在・O4） | 単独 |
| 08 | case-08_self_detection_language.md | language-profiles 未受領の単独起動で言語・FW を自己検出し architect に適用・dba 内部省略（O10 自己検出・後段） | 単独 |
| 09 | case-09_regression_db_constraint_deletion.md | U16 回帰検出（DB 制約 / トランザクション削除・dba 観点で削除側の防御消失を回帰指摘） | 委譲 |

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
