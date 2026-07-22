# pr-review 達成チェックリスト（PR Adapter）

`pr-review` スキルが **完了報告（Step 8）の前** に通過すべきルール群。
ID 体系・SSOT は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` を参照。

> **位置付け**: 本ファイルは **ルール ID 単位の達成チェック**。具体的な手順チェック（A/B/C/D グループ）は `completion-checklist.md` 側で運用。両者は併用関係（手順 = HOW、ルール = WHY）。
> **確認タイミング**: Step 7.5（完了前チェックリスト）と Step 8（完了報告）の間。
> **未通過時**: 該当項目を解消してから完了報告する。

---

## A. Universal ルール（全スキル共通）

> 規範本文・達成基準は **`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md`** を参照（プラグイン内 SSOT）。
> 適用範囲は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` セクション8 を参照。

上記 SSOT（`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` の U マップ表）の U1〜U16 全項目の通過を確認（各 U の 1 行要約・達成基準は同ファイルおよび `universal-rules-{environment,process,quality}.md` を参照）。

---

## B. PR Adapter ルール（pr-review 固有）

```
[ ] (P1)  PR 識別子をホワイトリスト正規表現で検証してから API に渡している
[ ] (P2)  Step 1.5 で認証情報を API 呼び出し前に確認している
[ ] (P3)  TFS Server 投稿時、ホストが credentials.json のホワイトリストに含まれることを確認している
[ ] (P4)  Step 5.5 で PR ブランチを worktree にチェックアウト、Step 7.5 でレビュー判定に応じて worktree を処理している（または SKIPPED 理由を記載）
[ ] (P5)  PR コメント投稿（サマリースレッド + インライン）を実施している（明示的にスキップ指示があった場合のみ免除）
[ ] (P6)  コメント本文サニタイズ（XSS / トラッキング画像 / 機密文字列伏字化）を投稿前に適用している
[ ] (P7)  予約文字（#/@/!）を \# / \@ / \! でエスケープ、または明示 Markdown リンク化している
[ ] (P8)  comment-sanitization.md セクション5.6 の投稿前チェックリスト（S1〜S9 / C1〜C6 / P1〜P4）を全項目通過している
[ ] (P9)  コード引用がコードフェンス + 言語識別子 + 引用範囲と start_line/line の完全一致を満たしている
[ ] (P10) 自著限定 + auto-resolve=false 指定時の dry-run を遵守している
    (P11) 廃止・欠番（キーワード除外撤廃）
[ ] (P12) status 更新時に connector の `marker:` で Bot 識別子（`[deep-code-review-plugin]`）を指定した reply を残している
[ ] (P13) 解消判定はコード修正系 / テスト追加系 / ドキュメント系の 3 系統で実施している
[ ] (P14) コメント本文・ファイルパス・threadId は jq --arg / --argjson / --rawfile 経由で JSON 構築している（コマンドインジェクション対策）
[ ] (P15) 全 API 呼び出しで HTTP コード取得 + case 分岐（401-403 即停止 / 429 指数バックオフ / 5xx 単発リトライ）を実装している
[ ] (P16) サマリースレッドが template/review-summary.md のヘッダブロック + 9 セクション順序を厳守し、各 H2 セクションを `<details><summary>` 折り畳み + 内部 HTML 記法で出力している（セクション 1〜3 の summary には件数 + 状態記号（>0 は ⚠ / 0 件は ✓ + 状態語）を付記）
[ ] (P17) 新サマリー投稿時、旧サマリースレッドを status=closed に更新している
[ ] (P18) Step 7.5 で completion-checklist.md A〜D グループ全項目を通過している
[ ] (P19) 完了報告に必須項目（モード / 件数 / 投稿件数 / 失敗 / 解消 / auto-resolve 状態 / チェックアウト / 復元 / PR 外操作なし宣言）を含めている
[ ] (P20) サマリースレッドに Finding ID 一覧の目次（## 検出した指摘・提案一覧（Finding ID））を含めている
[ ] (P21) 各インラインコメント本文の冒頭が `## [CR-NNN] [<致命度>] <タイトル>` の H2 見出し形式である
[ ] (P22) Finding ID と PR インラインコメントの対応関係（ID → コメント ID）が完了報告にトレース可能に記載されている
[ ] (P23) Step 7.4 で finding-thread-map.json をセッション作業領域に保存している
[ ] (P24) Pattern D 実行時に自動判定禁止 / 自著限定を遵守している
[ ] (P25) Pattern D 実行時に了承 reply 投稿 + status を wontFix（Azure）/ resolve（GitHub）に更新している
[ ] (P26) 完了時に PR の active なインラインスレッド一覧を取得し、残件数を確認している
[ ] (P27) 残スレッドがある場合は thread_id / file:line / 推奨アクションを完了報告に含めている
[ ] (P28) ユーザー修正指示 + Claude による修正コミット作成が成立した Finding ID で Pattern E（ack-fixed 相当）を実行している
[ ] (P29) Pattern E reply に修正コミットへの明示リンク（`[<sha7>](<commit-url>)`）を含めている
[ ] (P30) reply 投稿のみで status=active のまま放置している修正済み Finding が存在しない（必ず status=fixed まで更新）
[ ] (P31) サマリースレッドを **新規スレッド** として投稿し、既存サマリースレッドへの reply 投稿を行っていない（comment-posting.md セクション 7.5.0）
[ ] (P32) サマリー投稿は **インラインコメント全件投稿後の最終ステップ** として実施し、旧サマリーの closed 化 → 新サマリーの新規 POST の順序を厳守している
```

---

## C. 出力チェック（自動検証案）

投稿前に以下を検証する（ルール ID 判定は A/B 節が担う。ランタイム自動実行はしない）:

- **C-Auto-1**: 投稿前サニタイズ違反（裸の `#<数字>` / `@<英数字>` / `<img>` / 危険スキームリンク）の検出。未通過なら投稿中止（`${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization-escaping.md` 5.6.4 の簡易ガードと同一方式）
- **C-Auto-2**: PR 外への影響（`gh issue create` / `az boards work-item create` 等の禁止コマンド実行）の検出
- **C-Auto-3**: メインリポジトリ状態・残存 worktree の確認（worktree 不変条件）

bash 実装案は `${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization-escaping.md` 5.6.4 および `completion-checklist-autocheck-samples.md` E-3 / E-4（自動化検討時のみ Read）を参照。

---

## D. 未通過時の対応

> 本表は頻出の未通過パターンのみ記載（絞り込みは意図的）。記載外の ID はセクション A〜C の該当項目と `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` の達成基準に従って解消する。

| 未通過 ID | 対応 |
|----------|------|
| P1 | 識別子を正規表現で再検証してから処理を再開 |
| P2 / P3 | 認証情報の準備・ホワイトリスト確認をユーザーに依頼 |
| P4（worktree 処理） | レビュー判定に応じた worktree 処理（削除 or 維持）を確認 |
| P5（コメント未投稿） | サニタイズ・エスケープを再適用してから再投稿 |
| P6 / P7 / P8 | comment-sanitization.md セクション5.6 を再実行してから投稿 |
| P9 | 引用範囲を指摘箇所と一致するよう修正してから再投稿 |
| P10 | auto-resolve 方針違反（auto-resolve=false 指定時の status 更新等）は手動ロールバックせずユーザー報告 |
| P14 / P15 | jq + case 分岐実装を再確認・修正 |
| P16 / P17 | template/review-summary.md に従ってサマリーを書き直し再投稿 |
| P18 | completion-checklist.md の未通過項目を解消 |
| P31 / P32 | サマリーは既存スレッドへの reply ではなく新規スレッドとして再投稿し、旧サマリーは別途 status=closed へ更新する |
| U7（PR 外操作実施済） | 該当操作をユーザー報告し、ロールバック可否を判断してもらう |

---

## E. 関連リファレンス

- `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` — 全スキルのルール ID 体系
- `${CLAUDE_SKILL_DIR}/references/completion-checklist.md` — 手順ベースのチェックリスト（A〜D グループ）
- `${CLAUDE_SKILL_DIR}/references/local-checkout-review.md` — worktree 利用手順
- `${CLAUDE_SKILL_DIR}/references/comment-posting.md` — Step 7 詳細実装
- `${CLAUDE_SKILL_DIR}/references/comment-status-policy.md` — 自著限定・auto-resolve 既定
- `${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` — サニタイズ・エスケープ・投稿前チェックリスト
- `${CLAUDE_PLUGIN_ROOT}/references/scope-out-policy.md` — 別 PR 推奨禁止 / PR 外への影響禁止
