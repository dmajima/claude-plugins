# case-02 fetch-external=auto（ホワイトリスト適合 / 不適合）

仕様書なしで description に外部リンクが複数含まれ、`fetch-external=auto` が明示されるケース。ユーザー確認をスキップしてホワイトリスト一致 URL のみ自動 fetch し、不一致 URL は fetch_status: skipped で記録する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `spec` なし / `fetch-external=auto` / description に外部リンク 2 件（credentials.json 登録済みドメインの Backlog 課題 URL と、未登録ドメインの一般 HTTPS URL） |
| モード | 委譲呼び出し（auto 明示のため fetch 可否のユーザー確認なしで進行・非対話） |

## 分岐の根拠

SKILL.md「実行フロー」の分岐「fetch-external=auto? → Yes: ホワイトリスト一致のみ自動 fetch」、references/expected-behavior.md セクション 0.1「dry-run（既定）: 外部 fetch を行う前に『fetch 候補の一覧』をユーザーに提示する（`fetch-external=ask` 既定）。`fetch-external=auto` 明示時のみ確認スキップ可」、${CLAUDE_PLUGIN_ROOT}/references/safe-external-fetch.md セクション 1.2 判定ロジック（一致するエントリがある → auth_method で認証を付与して fetch / 一致しない → 自動 fetch しない）、expected-behavior.md セクション 3.4「ホワイトリスト不一致 → 『URL は検出したが認証情報未登録のためスキップ』と明示」、references/checklist.md セクション B の I2 / I3・セクション C の C-Auto-4（external-link の fetch_status に success/failure/skipped を明示）・セクション D の I2（fetch_status を "skipped" に）。

## 期待動作

- `fetch-external=auto` の明示により、fetch 候補一覧のユーザー承認（dry-run 提示）をスキップする（expected-behavior.md セクション 0.1）
- description から外部リンクを正規表現で抽出し（expected-behavior.md セクション 3.1、ASCII URL のみ）、各 URL のホストを credentials.json の domains / urls と照合する（safe-external-fetch.md セクション 1.2）
- ホワイトリスト一致の Backlog URL のみ fetch し、登録エントリの auth_method に従って認証を付与する（I2）
- 不一致の一般 URL は fetch せず、sources_used に `"fetch_status": "skipped"` として記録する（checklist セクション D の I2 対応、C-Auto-4）
- 取得結果には ${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md のサニタイズ規則を適用する（SKILL.md Step 3、I3）
- 内部 IP / IMDS / プライベート IP レンジへの fetch は行わず、タイムアウト・サイズ上限・リダイレクト制限を遵守する（safe-external-fetch.md セクション 2・3）
- 出力 JSON の sources_used に external-link エントリの fetch_status（success / skipped）を明示する（SKILL.md「出力」の JSON 例）
- 完了報告で fetch 成功件数とホワイトリスト不一致によるスキップ件数を明示する（expected-behavior.md セクション 7）

## 関連ケース

- case-01: 外部リンクなし（fetch 自体が発生しない対比）
- case-03: 矛盾検出（fetch を伴わない推論分岐）
