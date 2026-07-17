# pr-review evals

本ディレクトリは `pr-review` スキルの **AI の動作分岐検証ケース集**。
1 ケース 1 ファイルで、スキルの規範（SKILL.md / references/）に基づく分岐ごとに期待動作を定義する。

## ケース一覧

| case | ファイル名 | 検証する分岐 | モード |
|------|-----------|------------|--------|
| 01 | case-01_github_pr_standard.md | GitHub PR の初回標準レビュー正常系（認証 OK・インライン + サマリー投稿） | 対話 |
| 02 | case-02_azure_cloud_pr.md | クラウド Azure DevOps PR の正常系（az CLI 経路） | 対話 |
| 03 | case-03_unresolved_comments.md | 未解決コメントがある PR の確認フロー（解消判定の起点） | 対話 |
| 04 | case-04_quick_mode.md | mode=quick 指定時の簡易レビュー | 対話 |
| 05 | case-05_spec_argument.md | spec= 指定時の仕様整合性チェック付きレビュー | 対話 |
| 06 | case-06_tfs_ntlm_pr_review.md | オンプレ TFS Server の PR レビュー（NTLM 認証経路） | 対話 |
| 07 | case-07_pre_post_validation.md | 投稿前バリデーション 4 項目（PATH/ESCAPE/SANITIZE/TEMPLATE）の全通過 | 対話 |
| 08 | case-08_validation_failure_skip.md | バリデーション未通過時の投稿スキップ・修正後再試行 | 対話 |
| 09 | case-09_template_driven_posting.md | テンプレート駆動のコメント組み立て（署名は connector 委譲・本文に含めない） | 対話 |
| 10 | case-10_posting_order.md | 投稿順序（インライン → 旧サマリー close → サマリー） | 対話 |
| 11 | case-11_auth_missing.md | 認証情報欠落時のユーザー問い合わせ（API 不発行） | 対話 |
| 12 | case-12_empty_threads_skip.md | スレッド空配列時の Step 5 スキップ | 対話 |
| 13 | case-13_scope_out_ack.md | スコープ外了承処理（ack-scope-out / Pattern D） | 非対話 |
| 14 | case-14_ack_fixed.md | 修正完了確認処理（ack-fixed / Pattern E） | 非対話 |
| 15 | case-15_auto_resolve_false_dry_run.md | auto-resolve=false 指定時の dry-run（status 更新なし） | 非対話 |
| 16 | case-16_pattern_a_auto_resolve_default.md | Pattern A 既定の auto-resolve（解消確認 reply + status=fixed） | 非対話 |
| 17 | case-17_pattern_c_unresolved_reply.md | Pattern C 未解消スレッドへの再観察 reply（status=active 維持） | 非対話 |
| 18 | case-18_github_pr_review.md | GitHub PR URL フレーズでの起動・ホスト判定（トリガー検証） | 対話 |
| 19 | case-19_azure_devops_pr_review.md | Azure DevOps PR フレーズでの起動・env-setup 委譲（トリガー検証） | 対話 |
| 20 | case-20_simple_pr_review.md | 短い PR レビュー依頼フレーズでの起動・識別子解決（トリガー検証） | 対話 |
| 21 | case-21_pr_review_short.md | 最短の名詞句フレーズでの起動（トリガー検証） | 対話 |
| 22 | case-22_http_error_handling.md | HTTP エラーハンドリング（P15: 401 即停止 / 429 / 5xx） | 対話 |
| 23 | case-23_invalid_identifier_rejection.md | 不正 PR 識別子・ホワイトリスト外ホストの拒否（P1/P3 否定パス） | 対話 |
| 24 | case-24_worktree_ng_retained.md | worktree の NG 判定時維持・SKIPPED 例外（P4） | 対話 |
| 25 | case-25_sanitization_malicious_content.md | 悪性コンテンツのサニタイズ変換（P6/P7/P8） | 対話 |
| 26 | case-26_comment_posting_skip.md | コメント投稿不要明示時の投稿スキップ（P5 スキップパス） | 対話 |
| 27 | case-27_command_injection_jq.md | コマンドインジェクション対策（P14・jq --arg/--argjson/--rawfile） | 対話 |
| 28 | case-28_pattern_e_autonomous.md | Pattern E の自律発火（P28・修正指示 + 修正コミット成立） | 対話 |
| 29 | case-29_self_authored_only_resolve.md | 自著限定の auto-resolve（P10・他者起票は status 変更なし） | 非対話 |
| 30 | case-30_u16_regression_inline_propagation.md | U16 回帰指摘の PR インラインコメント伝播（観点別スキル検出→伝播投稿・P21/7.0.3） | 対話 |
| 31 | case-31_p13_category_conservative_exclusion.md | P13 解消判定の系統別分類と保守的除外（コード修正系=解消 / 設計・仕様系=未解決維持） | 非対話 |
| 32 | case-32_p26_p27_active_thread_report.md | P26/P27 残存 active インラインスレッドの確認と完了報告記載（残件 vs 全解消の対比） | 非対話 |
| 33 | case-33_p9_code_quote_range_compliance.md | P9 コード引用範囲の規範遵守（引用範囲ズレ・言語識別子欠落の検出→修正後再投稿の失敗パス） | 対話 |
| 34 | case-34_fetch_approval_gate.md | 外部 fetch の人的承認ゲート（fetch-external=ask 既定・AskUserQuestion 提示 → 承認後 spec-inference 委譲 / 拒否時スキップ・I2/U12） | 対話 |
| 35 | case-35_credentials_precheck_partial_info.md | 認証情報の部分欠落時の最小問い合わせ（TFS username あり value なし → パスワードのみ問い合わせ・credentials-precheck 1.5.2・P2/U12） | 対話 |
| 36 | case-36_pattern_d_defensive_branches.md | Pattern D 内部の防御的分岐（head_sha 不一致 Step1.4 / マッピング欠落 H2 フォールバック Step1.5 / 既解消スキップ Step1.6・P24） | 対話 |
| 37 | case-37_pattern_d_self_authored_guard_fallback.md | Pattern D の自著限定ガード（H2 フォールバックが他者起票に一致 → reply/status 変更せずスキップ・手動確認推奨・P24/P23） | 対話 |

## ケースファイルの構成

各ケースファイルは以下のセクションで構成する。

| セクション | 内容 |
|-----------|------|
| 入力 | 起動フレーズ / 対話・非対話モード |
| 分岐の根拠 | SKILL.md / references のどの規範に基づく分岐か（ファイル名・セクションを明記） |
| 期待動作 | 検証可能な期待動作の箇条書き |
| 関連ケース | 対になる分岐・前提となるケースへの参照 |
