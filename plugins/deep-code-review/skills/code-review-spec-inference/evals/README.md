# code-review-spec-inference evals

本ディレクトリは `code-review-spec-inference` スキルの **AI の動作分岐検証ケース集**。
1 ケース 1 ファイルで、スキルの規範（SKILL.md / references/）に基づく分岐ごとに期待動作を定義する。

## ケース一覧

| case | ファイル名 | 検証する分岐 | モード |
|------|-----------|------------|--------|
| 01 | case-01_spec_path_highest_priority.md | 仕様書明示（spec= 最高優先・外部 fetch 不発生） | 委譲（対話） |
| 02 | case-02_fetch_auto_whitelist_skip.md | fetch-external=auto（ホワイトリスト適合は自動 fetch / 不適合は fetch_status: skipped） | 委譲（非対話） |
| 03 | case-03_conflict_detection.md | 情報源間の矛盾検出（優先順位による採用 + conflicts フィールド出力） | 委譲（対話） |
| 04 | case-04_spec_inference_from_description.md | PR description 単独からの期待挙動推論（委譲・仕様書/外部リンクなし・外部 fetch 不発生） | 委譲（対話） |
| 05 | case-05_spec_with_external_links.md | 外部リンク付き PR での推論委譲（推論フロー Step 1-5 起動・承認 UI は pr-review 責務） | 委譲（対話） |
| 06 | case-06_fetch_ask_default_approval.md | fetch-external=ask 既定で pr-review 承認後に委譲された fetch 実行（承認済み候補の取得・spec-inference 側動作） | 委譲（対話） |
| 07 | case-07_fetch_failure_status.md | 外部 fetch 失敗（401/404/timeout）の failure 記録 | 委譲 |

## ケースファイルの構成

各ケースファイルは以下のセクションで構成する。

| セクション | 内容 |
|-----------|------|
| 入力 | 委譲 args / 委譲元（pr-review Step 3.5 / code-review）の対話・非対話文脈 |
| 分岐の根拠 | SKILL.md / references のどの規範に基づく分岐か（ファイル名・セクションを明記） |
| 期待動作 | 検証可能な期待動作の箇条書き |
| 関連ケース | 対になる分岐・前提となるケースへの参照 |

## 起動形態の軸について

本スキルは **委譲起動のみ**（pr-review Step 3.5 / code-review から Skill ツール経由で呼び出される）であり、ユーザーが直接起動する経路や対話 UI（`AskUserQuestion`）を **持たない**（SKILL.md「実行モード判定」）。したがって全ケースの起動形態は「委譲」で統一され、モード列の「委譲（対話）/委譲（非対話）」は **委譲元（pr-review 等）が対話文脈か非対話文脈か** を表す（本スキル自身が対話するわけではない）。外部 fetch の候補提示・ユーザー承認（dry-run）は呼び出し元 pr-review の責務であり、本スキルは承認済みの `fetch-external` ポリシーを受け取って動作する（`${CLAUDE_SKILL_DIR}/references/expected-behavior.md` セクション 0.1）。承認 UI そのものの検証は pr-review/case-34 が扱う。
