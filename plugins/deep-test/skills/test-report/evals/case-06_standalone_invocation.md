# case-06 単独起動（target-slug 自己解決・形式選択とも AskUserQuestion）

ユーザーがオーケストレータを経由せず test-report を直接起動する正常系。target-slug を自己解決し、報告形式の選択も AskUserQuestion で行うことを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | 「実績から報告書を作って」（target-slug の明示指定なし・形式指定なし） |
| 起動形態 | 単独（ユーザー直接起動・対話） |
| 前提 | 基準ディレクトリ配下に既存 `{target-slug}/` が複数存在し、いずれも run が 1 件以上記録済み。venv 構築可能 |

## 分岐の根拠

SKILL.md「実行モード判定」（ユーザーが直接起動 → 単独・対話: target-slug 解決〔data-locations.md 4 章のフロー〕から実施し、形式選択も AskUserQuestion で確認）・「実行フロー」ステップ 1〜6、`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 4.2（target-slug 解決フロー: 対話時は既存一覧 +「新規作成」を AskUserQuestion で提示）、`${CLAUDE_PLUGIN_ROOT}/references/report-format.md` 1 章（対話時の形式選択）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 2 章（生成前の最終バリデーション）。

## 期待動作

- target-slug が引数で渡されないため、data-locations.md 4.2 の解決フローで**既存 slug 一覧を AskUserQuestion で提示**して選択させる（憶測で 1 件に決め打ちしない）
- 対象 slug 確定後、最終バリデーション（`validate`）と evidence-auditor 監査を**省略せず**実施する（単独起動でもゲートは同一）
- 報告形式（Excel / Markdown）を **AskUserQuestion で確認**する（単独・対話のため既定 Markdown に自動決定しない）
- 選択形式の生成スクリプトを venv で実行し、`test-report_{target-slug}_{yyyyMMdd}.xlsx|.md` をセッション作業領域直下へ出力する
- 集計値はスクリプト標準出力の転記とし、LLM が手計算しない
- test-results.yaml を Edit / Write で編集しない（読み取りのみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 報告書 1 ファイル（`test-report_{target-slug}_{yyyyMMdd}.xlsx` または `.md`、セッション作業領域直下） |
| 標準出力（要約） | SKILL.md「引き渡し」正常時フォーマット（報告書絶対パス・総合判定・集計〔latest〕・NG 件数・未確認事項件数）。集計はスクリプト出力の転記 |
| 終了状態 | target-slug と形式を AskUserQuestion で確定 → バリデーション通過 → 生成完了 |

## 関連ケース

- case-01 / case-02: 委譲・対話での Excel / Markdown 生成（target-slug 確定済みの分岐との対比）
- case-04: 非対話での Markdown 既定（AskUserQuestion を行わない分岐との対比）
