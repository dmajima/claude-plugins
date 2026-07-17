# case-34 外部 fetch の人的承認ゲート（fetch-external=ask 既定・AskUserQuestion 提示）

`spec=` 未指定の PR で、description に外部リンク（Backlog 課題 / TFS Work Item 等）が含まれるケース。Step 3.5 で `code-review-spec-inference` へ委譲する **前** に、pr-review が fetch 候補一覧を `AskUserQuestion` でユーザーに提示し、承認後に `fetch-external=auto` 相当で委譲、拒否時は外部 fetch をスキップする **承認ゲート**（pr-review 責務）を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "この PR をレビューして"（`spec=` なし / PR description に外部リンク 2 件〈credentials.json 登録済みの Backlog 課題 URL と未登録の一般 HTTPS URL〉/ `fetch-external` 未指定＝既定 `ask`） |
| モード | 対話（fetch 候補提示 → ユーザー承認 → spec-inference へ委譲） |

## 分岐の根拠

`${CLAUDE_PLUGIN_ROOT}/skills/code-review-spec-inference/references/expected-behavior.md` セクション 0.1「fetch 承認の責務分担（dry-run）」（外部 fetch の候補提示とユーザー承認〈dry-run〉は **呼び出し元 `pr-review` の責務**。`pr-review` が `AskUserQuestion` で承認を得て、承認後 `fetch-external=auto` 相当で spec-inference に委譲する）、`${CLAUDE_PLUGIN_ROOT}/references/safe-external-fetch.md` セクション 5「dry-run（既定動作の推奨）」・セクション 1「ドメインホワイトリスト方式」（credentials.json 登録ホストのみ許可）、SKILL.md「Step 3.5: 期待挙動の推論」（`code-review-spec-inference` へ委譲）・「実行モード判定」（`fetch-external=ask`〈既定〉/ `auto` / `off`）、`${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` I2（外部 fetch のホワイトリスト準拠）/ U12（認証情報の取り扱い）。

> **差別化**: 本ケースは **pr-review 側の承認ゲート（AskUserQuestion 提示 → 委譲ポリシー確定）** を検証する。委譲を受けた `code-review-spec-inference` 側で「承認済み候補を fetch 実行する」動作は spec-inference/case-06 が扱う（責務分担の対）。`spec=` 明示時の仕様整合性チェックは case-05 が扱う（本ケースは `spec=` 未指定の自動推論経路）。

## 期待動作

- Step 3.5 で `code-review-spec-inference` へ委譲する前に、PR description から外部リンクを検出する（SKILL.md Step 3.5）
- `fetch-external` 未指定のため既定 `ask` として動作し、fetch 候補一覧（URL・種別・credentials.json 登録有無）を `AskUserQuestion` でユーザーに提示する（expected-behavior.md セクション 0.1・safe-external-fetch.md セクション 5）
- 候補提示時、credentials.json のホワイトリストに一致するもの（Backlog 課題 URL）を「fetch 可能」、未登録の一般 HTTPS URL を「認証情報未登録のためスキップ対象」として区別して提示する（safe-external-fetch.md セクション 1.2）
- ユーザーが承認した場合: `fetch-external=auto` 相当（承認済み）として `code-review-spec-inference` に委譲する。spec-inference 側は追加の承認 UI を出さずに承認済み候補を fetch する（expected-behavior.md セクション 0.1）
- ユーザーが拒否した場合: 外部 fetch を行わず、`fetch-external=off` 相当で委譲する（またはローカル情報源のみで推論継続）。承認されなかった旨をレビュー結果の制約に記録する
- 非対話起動で AskUserQuestion が使えない場合: 安全側フォールバックとして外部 fetch を保留（`off` 相当）し、「対話不可のため外部 fetch を保留」と明示する
- 承認 UI の提示・ポリシー確定は pr-review が担い、`code-review-spec-inference` に承認 UI を出させない（責務分担・expected-behavior.md セクション 0.1）
- 認証情報の値をユーザーに表示しない（存在有無のみ提示）（U12・SKILL.md 重要な制約）
- 本ゲートは PR の読み取り・推論の前処理であり、PR への書き込み（コメント投稿）は伴わない（U7・PR 外への影響なし）

## 関連ケース

- case-05: `spec=` 指定時の仕様整合性チェック付きレビュー（明示仕様書経路・承認ゲート不発生の対比）
- code-review-spec-inference/case-06: 承認後に委譲された spec-inference 側の fetch 実行（責務分担の対）
- code-review-spec-inference/case-02: `fetch-external=auto` 明示時の承認スキップ（CI/CD 経路の対比）
