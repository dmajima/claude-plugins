# code-review-frontend evals

本ディレクトリは `code-review-frontend` 観点別スキルの **AI の動作分岐検証ケース集**。
1 ケース 1 ファイルで、スキルの規範（SKILL.md / references/）に基づく分岐ごとに期待動作を定義する。

## ケース一覧

| case | ファイル名 | 検証する分岐 | 起動形態 |
|------|-----------|------------|---------|
| 01 | case-01_delegated_ui_change.md | 委譲（UI 変更あり）: web-designer 起動・観点項目を網羅した中間レポート返却 | 委譲 |
| 02 | case-02_standalone_scope_out.md | 単独実行 + バックエンド / XSS 等スコープ外の混在（振分け・progress.md 自スキル作成） | 単独 |
| 03 | case-03_frontend_review.md | フロントエンドレビューフレーズでの起動（トリガー検証） | 単独 |
| 04 | case-04_accessibility_review.md | アクセシビリティ確認フレーズでの起動（トリガー検証） | 単独 |
| 05 | case-05_language_profiles_applied.md | language-profiles 受領と web-designer 適用（O10・React+CSS 横断） | 委譲 |
| 06 | case-06_self_detected_profiles.md | language-profiles 未受領時の自己検出（O10・Vue+SCSS） | 単独 |
| 07 | case-07_defensive_code_regression.md | 防御コード削除の回帰検出（U16・a11y 属性 / エラー表示 UI） | 委譲 |
| 08 | case-08_liquid_template_review.md | Liquid / DotLiquid テンプレートの評価（html.md 3.7 テンプレートエンジン観点） | 委譲 |
| 09 | case-09_wcag_accessibility.md | WCAG 個別達成基準の網羅評価（コントラスト / キーボード / ARIA / 代替テキスト） | 委譲 |

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
