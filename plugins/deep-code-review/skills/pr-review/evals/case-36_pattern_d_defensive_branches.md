# case-36 Pattern D 内部の防御的分岐（head_sha 不一致 / マッピング欠落 / 既解消スキップ）（P24）

スコープ外了承（Pattern D）の実行中に、force-push による head_sha 不一致（Step 1.4）・マッピング欠落の H2 見出しフォールバック（Step 1.5）・既解消スレッドのスキップ（Step 1.6）の 3 防御分岐が同時に発生するケース。正常系の case-13 では通らない Pattern D 内部の防御ロジックを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "CR-002 と CR-005 はスコープ外として了承、スレッド閉じて"（pr-review を `ack-scope-out=CR-002,CR-005` 相当で起動） |
| モード | 対話 |
| PR / マッピング状態 | PR が force-push で head_sha が書き換わっている。`finding-thread-map.json` は存在するが CR-005 のマッピングが欠落。CR-002 は既に `wontFix` 済み |

## 分岐の根拠

skills/pr-review/references/scope-out-pattern-d.md セクション2（`ack-scope-out=` 受領時は Step 1〜8 をスキップし本フローのみ実行）・Step 1.4（head_sha 整合性チェック）・Step 1.5（マッピング欠落フォールバック）・Step 1.6（既解消スレッドのスキップ判定）、references/comment-posting.md セクション7.0.1（インライン本文の H2 見出し形式）、skill-rules-matrix.md P23 / P24 / P25 / P26 / P27。

## 期待動作

- 起動: ユーザーが対話で「スコープ外として了承」と指示 → 通常レビューフロー（Step 1〜8）をスキップして Pattern D フローのみ実行する（scope-out-pattern-d.md セクション2）
- Step 1: `finding-thread-map.json` から CR-002 / CR-005 の thread_id 解決を試みる
- Step 1.4: 保存 `head_sha` と PR の現在の head SHA を比較 → **不一致**。force-push 等でブランチが書き換わった可能性を警告し（thread_id は不変だが file:line が旧 SHA 基準）、`AskUserQuestion` で「続行 / 中止」を確認する。続行指示時は file:line に依存しない thread_id ベースの reply / status 更新に限定する（Step 1.4 判定表）
- Step 1.5: CR-005 のマッピングが `finding-thread-map.json` に存在しないため、PR の現在スレッド一覧を取得し、各スレッド本文冒頭の `## [CR-NNN] [<致命度>] <タイトル>` の **H2 見出し形式**（comment-posting.md セクション7.0.1）で CR-005 を特定する。特定できないスレッドは「不明」として処理せず完了報告に含める
- Step 1.6: 対象スレッドの現在 status を API 取得。CR-002 が既に `wontFix`（解消済み）→ **処理スキップ**し、完了報告に「CR-002: 既に解消済み（status=wontFix）のためスキップ」と記載する（重複 reply 防止）。CR-005 は `active` のため Step 3〜4 を続行する
- Step 3〜4: active な CR-005 に了承 reply を投稿し、status を wontFix（Azure）/ resolve（GitHub）に更新する（P25）
- Step 5〜6: 最終状態を検証（サマリーのみ active か）し、完了報告に処理 / スキップ / 不明の内訳を明記する（P26 / P27）
- （以下は検出してはならない誤り）
    - head_sha 不一致を無視して file:line 基準の処理を続行する（Step 1.4 違反）
    - マッピング欠落の CR-005 を H2 見出しフォールバックで探索せず即エラー終了する（Step 1.5 違反）
    - 既に wontFix 済みの CR-002 に重複 reply を投稿する（Step 1.6 違反・スレッドノイズ）

## 関連ケース

- case-13: スコープ外了承処理の正常系（マッピング解決成功・head_sha 一致）
- case-14: 修正完了確認処理（ack-fixed / Pattern E）
