# case-06 fetch-external=ask（既定）で pr-review 承認後に委譲された fetch 実行

`fetch-external=ask`（既定）で外部リンクがあるケースにおける **spec-inference 側の動作** を検証する。候補提示とユーザー承認（dry-run）は呼び出し元 pr-review の責務であり、本スキルは承認済みポリシー（`auto` 相当）を受け取って承認済み候補を fetch する。承認 UI を本スキルが提示しないことを確認する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `spec` なし / description に credentials.json 登録済みドメインの外部リンク 1 件 / `fetch-external=auto` 相当（pr-review が既定 `ask` でユーザー承認を取得後、承認済みとして委譲） |
| モード | 委譲呼び出し（pr-review が承認取得済み・本スキルは非対話で fetch 実行） |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/expected-behavior.md` セクション 0.1「fetch 承認の責務分担（dry-run）」（外部 fetch の候補提示とユーザー承認〈dry-run〉は **呼び出し元 pr-review の責務**。`fetch-external=ask` 既定では pr-review が候補一覧を提示し承認を得て、承認後 `fetch-external=auto` 相当で spec-inference に委譲する。本スキルは委譲起動のみで対話 UI〈AskUserQuestion〉を持たない）、SKILL.md「実行モード判定」（`fetch-external=auto`: 承認済みとして spec-inference が候補を fetch・本スキルは追加の確認をしない）、`${CLAUDE_PLUGIN_ROOT}/references/safe-external-fetch.md` セクション 1.2（ホワイトリスト判定）、references/checklist.md セクション B の I2 / I3。

> **差別化**: 本ケースは `fetch-external=ask` 既定における **spec-inference 側の fetch 実行**（承認済み候補の取得）を検証する。承認 UI の提示・承認取得そのもの（pr-review 責務）は pr-review/case-34 が扱う。`auto` 明示（CI/CD で承認ステップ自体が無い経路）のホワイトリスト適合/不適合は case-02、fetch 失敗（401/404）は case-07 が扱う。

## 期待動作

- `fetch-external=ask` 既定における候補提示・ユーザー承認は **呼び出し元 pr-review が実施済み** であり、本スキルは承認 UI（AskUserQuestion）を提示しない（expected-behavior.md セクション 0.1・SKILL.md 実行モード判定＝委譲起動のみ）
- pr-review から承認済み（`fetch-external=auto` 相当）として委譲を受け、承認済み候補を追加確認なしで fetch する（SKILL.md 実行モード判定・expected-behavior.md セクション 0.1）
- fetch 前にホワイトリスト照合（safe-external-fetch.md セクション 1.2）を行い、登録エントリの `auth_method` に従って認証を付与して取得する（I2）
- 取得結果に comment-sanitization.md のサニタイズ規則を適用する（I3）
- sources_used の external-link エントリに `fetch_status: success` を記録する（checklist セクション C の C-Auto-4）
- pr-review 側で承認が得られず `fetch-external=off` 相当で委譲された場合は fetch せず、sources_used に該当エントリを `fetch_status: skipped`（理由: 非承認）として記録し、その旨を conflicts / 制約事項に明記する
- 本スキル自身が承認可否をユーザーに問い合わせない（承認判断は pr-review が完了済み・責務分担）

## 関連ケース

- pr-review/case-34: `fetch-external=ask` 既定の承認ゲート（候補提示 → 承認 → 委譲。pr-review 側の責務・本ケースと対）
- case-02: `fetch-external=auto` 明示（承認ステップ自体が無い CI/CD 経路の対比）
- case-07: fetch 失敗（401/404）のハンドリング
