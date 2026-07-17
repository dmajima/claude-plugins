# case-05 外部リンク先資料からの期待挙動推論（委譲・推論フロー Step 1-5 起動）

PR description 内の外部リンク先資料も取得して期待挙動を補完する委譲起動ケース。外部リンクを含む推論フロー全体（抽出 → ホワイトリスト照合 → fetch → サニタイズ → 矛盾検出）の起動を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `spec` なし / PR description に外部リンクあり（credentials.json 登録済みドメイン）/ `fetch-external` は呼び出し元 pr-review が確定して受け渡し |
| モード | 委譲呼び出し（pr-review Step 3.5 から Skill ツール経由・対話） |

## 分岐の根拠

SKILL.md「責務」「トリガー条件」（外部リンク先資料〈Backlog / TFS Boards / Wiki 等〉から期待挙動を抽出）、SKILL.md「実行モード判定」（本スキルは **委譲起動のみ**・`fetch-external` 引数で外部 fetch 動作を切替。承認 UI 自体は呼び出し元 pr-review の責務）、SKILL.md「実行フロー」Step 2 の分岐（`fetch-external=auto?` → Yes: ホワイトリスト一致のみ自動 fetch / No: ユーザー承認 or off=スキップ）、`${CLAUDE_SKILL_DIR}/references/expected-behavior.md` セクション 3（外部リンクの抽出と fetch）・セクション 3.1（抽出対象パターン・ASCII URL のみ）・セクション 0.1（fetch 承認の責務分担）、`${CLAUDE_PLUGIN_ROOT}/references/safe-external-fetch.md`（ドメインホワイトリスト方式）、`${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md`（取得結果サニタイズ）、references/checklist.md セクション B の I2 / I3 / I4 / I5。

> **差別化**: 本ケースは **委譲起動での推論フロー全体（Step 1〜5）の起動** と、外部リンクを含む推論の成立を検証する。`fetch-external=ask` 既定で pr-review が承認を得た後に委譲された spec-inference 側の fetch 実行は case-06、`auto` のホワイトリスト適合/不適合は case-02、fetch 失敗（401/404/timeout）は case-07 が扱う。

## 期待動作

- `pr-review` Step 3.5 から委譲され、対話 UI（AskUserQuestion）を出さずに非対話で期待挙動サマリを生成する（SKILL.md「実行モード判定」＝委譲起動のみ）
- Step 1: description / コメントから外部リンクを情報源候補（優先度 3: 外部リンク先資料）として収集する（I1・expected-behavior.md セクション 1 表）
- Step 2: 外部リンクを正規表現で抽出（expected-behavior.md セクション 3.1・ASCII URL のみ・Unicode ホモグラフ対策）し、safe-external-fetch.md のドメインホワイトリスト方式で照合する（I2）
- Step 2: 受け渡された `fetch-external` ポリシー（`ask` は pr-review が承認済みで委譲・`auto` / `off`）に従って fetch 可否を分岐する。fetch 候補提示（承認 UI）は呼び出し元 pr-review の責務であり、本スキルは承認 UI を出さない（expected-behavior.md セクション 0.1・SKILL.md 実行モード判定）
- Step 3: 取得結果に comment-sanitization.md のサニタイズ規則を適用する（I3）
- Step 5: 複数情報源間（description vs 外部資料等）の矛盾を検出し conflicts フィールドに記録する（I4）
- 出力 JSON は 5 フィールド構造とし、sources_used の external-link エントリに fetch_status（success / failure / skipped）を明示する（I5・checklist セクション C の C-Auto-4）
- 内部 IP / IMDS / プライベート IP レンジへの fetch を行わず、タイムアウト・サイズ上限・リダイレクト制限を遵守する（safe-external-fetch.md セクション 2・3）

## 関連ケース

- case-04: 外部リンクなし・description 単独からの委譲推論（外部 fetch 不発生の対比）
- case-06: `fetch-external=ask` 既定で pr-review 承認後に委譲された fetch 実行（承認済み候補 fetch の対比）
