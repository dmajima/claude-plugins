# 完了前チェックリスト詳細（A〜C）: レビュー実施手順 / PR コメント投稿 / ルール順守

> **索引（親）**: [completion-checklist.md](completion-checklist.md)
> 本ファイルは `pr-review` 完了前チェックリストの詳細サブファイル。グループ **A / B / C** を収録。
> グループ **D / E / F** および「7. 関連リファレンス」は
> [completion-checklist-reporting.md](completion-checklist-reporting.md) と索引を参照。

---

## A. レビュー実施手順チェックリスト

### A-0: フロー自動進行チェック（Step 8 完了報告前に確認）

```
[ ] (A-0-1) connector からの読み取り結果受領後、ユーザー入力を待たずに次ステップへ
      自動進行したか（停止した場合は本項目を FAIL とし、原因を完了報告に記載）
[ ] (A-0-2) code-review 結果受領後、ユーザー入力を待たずに Step 7（PR コメント投稿）へ
      自動進行したか
[ ] (A-0-3) Step 7 の各投稿操作（インライン → 旧サマリー closed → 新サマリー POST）が
      ユーザー入力なしで連続実行されたか
[ ] (A-0-4) フロー中にユーザーの手動介入（「実施」「投稿」等）が必要になった箇所は
      0 件か（0 件でない場合は FAIL とし、介入箇所と原因を完了報告に記載）
```

> **フロー停止検知時の自己修復**: フローの停止が検知された場合（= ユーザーが手動で「実施」「投稿」等を入力した場合）、
> 停止箇所と原因を特定し、完了報告の「未確認事項・制約」に記載する。
> 停止後のフローは残りのステップを **すべて自動で** 完了する（「停止したから残りもユーザー確認で」とはしない）。

### A-1: スコープ確定（Step 1）

```
[ ] (A-1-1) PR 識別子が正規表現バリデーションに通過している
[ ] (A-1-2) ホスト判定（GitHub / クラウド ADO / オンプレ TFS）が完了している
[ ] (A-1-3) 認証情報の事前確認（Step 1.5）が完了している
```

### A-2: worktree 環境（Step 5.5）

```
[ ] (A-2-1) setup.sh で worktree を作成（または既存 worktree を更新）している
[ ] (A-2-2) worktree の HEAD SHA が PR の最新 head と一致している
       （または SKIPPED の場合、理由を「## 9. レビュー実施環境」に明記している）
[ ] (A-2-3) PR との同等性を確認している（差分行数の一致 等）
[ ] (A-2-4) ビルド/起動確認を worktree 内で実施した、または SKIPPED 理由を記載している
[ ] (A-2-5) メインリポジトリのブランチ・作業状態が変更されていない
[ ] (A-2-6) レビュー判定 OK の場合: teardown.sh で worktree を削除している
[ ] (A-2-7) レビュー判定 NG の場合: worktree を維持し、再レビュー時に利用する旨を報告している
```

### A-3: レビュー本体（Step 6）

```
[ ] (A-3-1) `code-review` オーケストレーターに委譲して観点別レビューを実施している
[ ] (A-3-2) プロジェクト規約（CLAUDE.md / .claude/rules/ 等）を読み込んでいる
[ ] (A-3-3) 仕様書（spec=<path>）が指定されていれば読み込んでいる
[ ] (A-3-4) レビューモード（standard / quick）が確定している
```

### A-4: 既存指摘の解消判定（再レビュー時のみ）

```
[ ] (A-4-1) 既存自著スレッドの一覧を取得している
[ ] (A-4-2) 各スレッドを Pattern A / C のいずれかに分類している
[ ] (A-4-3) 自著判定（uniqueName / login）が完了している
    (A-4-4) 廃止・欠番（キーワード除外撤廃。ルール ID 軸の P11 廃止に対応 → `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` P11）
[ ] (A-4-5) `auto-resolve=false` 指定時は status 変更を行っていない
[ ] (A-4-6) 各スレッドへの reply で connector 呼び出し時に `marker:` で Bot 識別子（`[deep-code-review-plugin]`）を指定している
```

---

## B. PR コメント投稿チェックリスト（必須）

> 別途指示なき限り、標準レビュー / 簡易レビューに関わらず PR へのコメント記載は **必須**（`pr-review` SKILL.md セクション 1 の方針）。

### B-1: コメント投稿要件

```
[ ] (B-1-1) サマリースレッドを PR 全体宛に投稿している（`threadContext == null`）
[ ] (B-1-2) サマリー本文がテンプレート `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/template/output/review-summary.md` に準拠している（各 H2 セクションが `<details><summary>` 折り畳み + 内部 HTML 記法）
[ ] (B-1-3) サマリー冒頭のヘッダブロックに必須項目（レビュー結果（統合フィールド）/ 件数 / 実施日時 / 対象 head SHA / レビュー対象 / レビューモード）が含まれている
[ ] (B-1-4) Critical / High / Medium の指摘はインラインコメントとして該当行に投稿している
[ ] (B-1-5) インラインコメントの `start_line`/`line` または `rightFileStart`/`rightFileEnd` が指摘箇所と一致している
[ ] (B-1-6) 旧サマリースレッドは `status=closed` に更新している（再レビュー時）
[ ] (B-1-7) コメント投稿の失敗件数を完了報告に明記する準備ができている
[ ] (B-1-8) サマリースレッドのヘッダブロック直後に Finding ID 一覧の目次（`## 検出した指摘・提案一覧（Finding ID）`）を含めている
[ ] (B-1-9) 各インラインコメント本文の冒頭が `## [CR-NNN] [<致命度>] <タイトル>` の H2 見出し形式である
[ ] (B-1-10) サマリースレッドを **新規スレッド** として投稿している（既存サマリースレッドへの reply として投稿していない・`comment-posting.md` セクション 7.5.0 参照）
[ ] (B-1-11) サマリースレッドの投稿は **インラインコメント全件投稿後の最終ステップ** として実施している（投稿順序: インライン → 旧サマリー closed → 新サマリー POST）
```

### B-1.5: Finding ID 採番要件

```
[ ] (B-1.5-1) すべての指摘・改善提案・スコープ外指摘に Finding ID（`CR-NNN`）を採番している（軽微なものを含めて漏れなし）
[ ] (B-1.5-2) ID は統合サマリ全体で連続採番されている（Issues → Suggestions → Scope-out の通番）
[ ] (B-1.5-3) ID の番号空間で重複がない（`CR-001` が 2 件以上ないことを確認）
[ ] (B-1.5-4) コード側に既存 `CR-XXX` マーカーがある場合、`REV-NNN` 等の別プレフィクスを使用している
[ ] (B-1.5-5) 再レビュー時、新規発見指摘に新規 ID を割り当て、解消判定セクションでは過去 ID を参照している
```

### B-1.6: Finding ID → Thread ID マッピング永続化（Pattern D 連携）

```
[ ] (B-1.6-1) Step 7.4 で finding-thread-map.json をセッション作業領域に保存している
[ ] (B-1.6-2) マッピングに pr_id / head_sha / review_run / mappings[] が含まれている
[ ] (B-1.6-3) 各 mapping エントリに finding_id / thread_id / comment_id / file_path / line_range / severity / category / title が含まれている
[ ] (B-1.6-4) 完了報告にマッピングの保存パスを明記している（後続 ack-scope-out 操作で参照されるため）
```

### B-1.7: 最終状態（サマリースレッドのみ active）

> 対応すべき指摘がすべて対応された場合、PR 上で **active な未解決スレッドはサマリースレッド 1 件のみ** であることを確認する。
> 未対応スレッドが残る場合は完了報告に一覧を含めユーザーへ次のアクションを提示する。

```
[ ] (B-1.7-1) 完了時点で PR の active なインラインスレッド一覧を取得している
[ ] (B-1.7-2) active なインラインスレッドが 0 件の場合、「サマリーのみ active」状態を達成している旨を完了報告に明記している
[ ] (B-1.7-3) active なインラインスレッドが残る場合、その一覧（thread_id / file:line / Finding ID 推定 / 推定パターン C/D/E 適用候補。A は自動解消済みのため通常残らない）を完了報告に含めている
[ ] (B-1.7-4) 残スレッドへの推奨アクション（コード修正・ack-fixed 指示・ack-scope-out 指示・手動 resolve）をユーザーに提示している
[ ] (B-1.7-5) サマリースレッドが PR 全体宛で 1 件のみ active であり、複数の active サマリーが残っていない（旧サマリーは status=closed 済み）
[ ] (B-1.7-6) Verdict に関わらず（OK / Needs Attention / Needs Work のいずれでも）サマリースレッドが新規投稿されたか（Verdict = OK でサマリー投稿を省略していないか）
```

### B-1.8: 修正完了確認（Pattern E・必須）

> **修正コミットを作成した時点で必ず Pattern E（status=fixed 化）まで実行する**。reply 投稿のみで status=active 放置は禁止（不具合の根本原因）。

```
[ ] (B-1.8-1) ユーザー修正指示 + Claude による修正コミット作成が成立した Finding ID をすべて把握している
[ ] (B-1.8-2) 各 Finding ID 対応スレッドへ Pattern E reply（修正コミット明示リンク付き）を投稿している
[ ] (B-1.8-3) 各 Finding ID 対応スレッドの status を fixed（Azure DevOps）/ resolved（GitHub）に更新している
[ ] (B-1.8-4) Pattern E reply に修正コミット SHA・URL の明示リンク `[<sha7>](<commit-url>)` を含めている
[ ] (B-1.8-5) status=active のまま reply のみ放置されている修正済み Finding が無いことを確認している
```

### B-2: コメント本文サニタイズ・コード引用・投稿先指定（必須）

> 詳細チェックは **`${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` セクション 5.6** を SSOT として参照。重複定義は廃止（2026-04 改訂）。

```
[ ] (B-2) セクション5.6.1 サニタイズチェックリスト（S1〜S9）を全項目通過している
[ ] (B-3) セクション5.6.2 コード引用チェックリスト（C1〜C6）を全項目通過している
[ ] (B-4) セクション5.6.3 投稿先指定チェックリスト（P1〜P4）を全項目通過している
```

未通過時は本ファイルではなく `comment-sanitization.md` 側を参照して修正（修正は SSOT で 1 度実施）。

---

## C. ルール順守チェックリスト

> 各項目の規範は ID 軸の `checklist.md` および対応 SSOT で管理。本セクションは **手順上の確認項目** のみ残す。

### C-1: 別 PR 推奨禁止 / PR 外影響禁止

> SSOT: `${CLAUDE_PLUGIN_ROOT}/references/scope-out-policy.md` セクション1, セクション1.5
> ID 軸: `checklist.md` U7, U8

```
[ ] (C-1) 出力本文に「別 PR / 別チケット / Issue 起票」等の禁止文言がない（→ scope-out-policy.md セクション1 / セクション3.2）
[ ] (C-1.5) Work Item / Issue / Boards / 通知 / Wiki / 別 PR / 別ブランチ / リポジトリ設定への書き込みを行っていない（→ セクション1.5）
```

### C-2: 統合サマリの統一フォーマット

> SSOT: `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/output/output-format.md`
> ID 軸: `checklist.md` P16

```
[ ] (C-2) template/review-summary.md の 9 セクション + ヘッダブロックを厳守し（各 H2 セクションは `<details><summary>` 折り畳み + 内部 HTML 記法、セクション 1〜3 の summary には件数 + 状態記号（>0 は ⚠ / 0 件は ✓ + 状態語）を付記）、該当なしのセクションも `<details>` ブロックを残し本文に「該当なし」と明記している
```

### C-3: auto-resolve / 自著限定

> SSOT: `${CLAUDE_SKILL_DIR}/references/comment-status-policy.md` セクション0.1〜0.4
> ID 軸: `checklist.md` P10

```
[ ] (C-3) auto-resolve=false 指定時に status 更新していない / 他者起票スレッドに変更していない
```

---

> **続き**: グループ D（完了報告）・E（自動チェックの実装案）・F（未通過時の対応）は
> [completion-checklist-reporting.md](completion-checklist-reporting.md) を参照。
> **索引に戻る**: [completion-checklist.md](completion-checklist.md)
