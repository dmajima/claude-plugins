# case-22 PR Thread ID の state.yaml 転記（C19 成功分岐・finding-thread-map.json 既存）

`pr-review` から委譲された再レビューで、前回投稿時に生成された `finding-thread-map.json` が既存のケース。Step 8.5-4 で map を Finding ID 照合し、各 finding の `pr_thread_id` / `pr_thread_url` / `pr_thread_status` を state.yaml へ転記する **C19 の成功分岐** を検証する。map 未生成で全フィールド null となる case-12 と対になる。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `scope=pr-diff`（差分・コンテキスト・project-rules-summary・language-profiles は pr-review から受領）/ 前回 state.yaml あり（再レビュー・`review_round` >= 2）/ 前回ラウンドの PR 投稿で生成された `finding-thread-map.json` がセッション作業領域に既存（前回投稿済み finding の Finding ID → Thread ID 対応を含む） |
| モード | 委譲呼び出し（pr-review から Skill ツール経由・標準） |

## 分岐の根拠

`${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` C19「PR Thread ID の記録（PR レビュー時、投稿済み全 finding に `pr_thread_id` を state.yaml に記録する）」、references/flow/flow-steps-output.md セクション 8.5-4「PR Thread ID の記録」（`pr_thread_id` / `pr_thread_url` / `pr_thread_status` を記録し `finding-thread-map.json` と整合性を保つ・「`finding-thread-map.json` が存在する場合はその内容を Finding ID で照合し、state.yaml の各 finding に Thread ID を転記する。存在しない場合は Thread ID 関連フィールドを `null` のままとする」）、同セクション 8.5-4「Thread ID の受渡しインターフェース」表（`pr-review` → `code-review`: `pr-review` が投稿後 `finding-thread-map.json` をセッション作業領域に保存〈pr-review Step 7.4〉・取得タイミング Step 8.5）、同セクション 8.5-5「投稿結果に応じた finding.status 更新」、`${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` C16（前回 state.yaml 読み込み・`review_round` +1）/ C12（pr-review からの委譲のみ受領）。

> **差別化**: 本ケースは `finding-thread-map.json` が **既存**（前回投稿済み）で Thread ID を **転記する成功分岐**（C19）を検証する。case-12 は同じ `scope=pr-diff` 委譲だが `finding-thread-map.json` が **未生成** で `pr_thread_id` が `null` になる分岐（C22 内部データ返却が主眼）を扱う。本ケースは C19 の Thread ID 転記そのものを主眼とする。

## 期待動作

- Step 0-P: 前回 state.yaml を読み込み `review_round` を +1 する（C16。再レビュー文脈）
- Step 1: `scope=pr-diff` のため pr-review から渡された差分を使用し、PR 識別子（URL/ID）を直接処理しない（C12・flow.md Step 1）
- Step 8.5-2: state.yaml を規定パス（`.claude/.local/plugins/deep-code-review/{branch}/{timestamp}/`）に生成する
- Step 8.5-4: セッション作業領域の `finding-thread-map.json` が既存であることを検出し、その内容を **Finding ID で照合** して各 finding に `pr_thread_id`（Azure DevOps thread ID / GitHub comment ID）・`pr_thread_url`（PR コメントへの完全 URL）・`pr_thread_status`（active / fixed / wontFix / closed）を転記する（C19・flow-steps-output.md セクション 8.5-4）
- 前回投稿済みで map に対応がある finding は Thread ID 3 フィールドが埋まり、`null` のまま残らない（C19・8.5-7 検証「投稿済みの全 finding に `pr_thread_id` が記録されている」）
- Step 8.5-5: 投稿成功の finding は `finding.status = open` / `pr_thread_status = active` を維持し、投稿失敗（`post_failed: true`）の finding は `pr_thread_id = null` として再投稿対象にマークする（flow-steps-output.md セクション 8.5-5）
- map に対応が無い新規 finding（今回ラウンドで新規採番）は `pr_thread_id` を `null` のままとし、pr-review 投稿後の後続転記に委ねる（8.5-4 の受渡しインターフェース）
- Step 8: 統合結果は対話文なしの内部データとして返却する（C22。pr-review 委譲時）
- 本スキルから `pr-review` を呼び出さない（循環参照防止・C12）

## 関連ケース

- case-12: `finding-thread-map.json` 未生成で `pr_thread_id` が `null`（C19 の null 分岐・C22 内部データ返却が主眼の対比）
- case-03: 前回 state.yaml ありの再レビュー（remaining_issues 引き継ぎ・再レビュー文脈の前提）
