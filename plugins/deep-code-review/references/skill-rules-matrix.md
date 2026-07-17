# スキル横断ルール・マトリクス（プラグイン共通）

`deep-code-review` プラグインが配下に持つ全スキルが守るべき **共通ルール** と、スキル固有の **満たすべき達成基準** を ID 体系で整理した SSOT。
各スキルは本ファイルを片方向参照し、自スキルに該当する ID 群を `references/checklist.md` に列挙する。

> **位置付け**: `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md`（プラグイン直下 references）。
> 規範ロジックとして個別スキルに依存しない（共通モジュールがクライアントを知らない原則）。
> ただし規範本文の SSOT が個別スキル内（`skills/code-review/references/output/` 等）にある場合、SSOT 列でのポインタ参照は許容する（`references/CLAUDE.md` の許容規定「適用先スキルを示すポインタ記載は除く」に準拠。SSOT の昇格判断は `roadmap.md` セクション 2 の既知課題として管理）。
> 各スキルは自身の `references/checklist.md` から本ファイルへ片方向参照する。

---

## 1. ルール ID 体系

| プレフィクス | カテゴリ | 適用対象 |
|------------|---------|---------|
| `U` | Universal（プラグイン全スキル共通） | すべてのスキル |
| `O` | Observation Skill（観点別レビュースキル共通） | code-review-implementation / -testing / -security / -architecture / -frontend |
| `C` | Coordinator（オーケストレーター） | code-review |
| `P` | PR Adapter（PR ホスト連携） | pr-review |
| `I` | Inference Skill（推論支援スキル） | code-review-spec-inference |
| `E` | Environment Skill（環境構築スキル） | env-setup |

---

## 2. Universal ルール（全スキル共通・MANDATORY）

> **SSOT**: 各 ID の詳細定義（規範本文・達成基準）は **`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md`** にプラグイン内で集約済み。本マトリクスは ID と概要のみを示す。

| ID | ルール | 達成基準（概要） | プラグイン内 SSOT |
|----|------|---------|------|
| **U1** | スキル構成規約への準拠 | `SKILL.md` 最小構成 + `references/` 細分化 + `scripts/` の業務単位サブフォルダ分類 | `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U1 |
| **U2** | ファイル文字コード・改行コードの維持 | 既存ファイルを編集する際は元のエンコーディング・改行コードを変えない | `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U2 |
| **U3** | ローカルデータ領域の規約遵守 | バージョン管理対象外データは `.claude/.local/{category}/{name}/...` 配下に置く | `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U3 |
| **U4** | セッション作業領域の規約遵守 | 中間生成物は `.claude/.local/work/{yyyyMMdd_nn_summary}/workspace/`、Python venv は `workspace/.venv/` | `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U4 |
| **U5** | 進捗管理ルール | 3 タスク以上 or マルチエージェント作業時は `progress.md` を作成・維持 | `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U5 |
| **U6** | ポータブルパス記法の遵守 | 自己参照は `${CLAUDE_SKILL_DIR}` / プラグイン内参照は `${CLAUDE_PLUGIN_ROOT}` を使う | `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U6 |
| **U7** | PR 外への影響禁止 | Work Item / Issue / Boards / 別 PR / Wiki / 通知システム等への書き込み禁止（ユーザー明示要求時のみ例外） | `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U7 → `scope-out-policy.md` セクション1.5 |
| **U8** | 別 PR 推奨の禁止 | 「別 PR で対応してください」「別チケット化してください」等の文言を使わない。スコープ外指摘は専用セクションに分離 | `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U8 → `scope-out-policy.md` セクション1, セクション3 |
| **U9** | エージェント並列起動 | 独立した観点のエージェントは 1 メッセージ内で並列起動（Independent 型） | `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U9 → `agents.md` セクション3 |
| **U10** | エージェント共通指示の付与 | プロジェクト規約参照指示・指摘必須項目・スコープ判定・別 PR 推奨禁止をプロンプト末尾に必ず含める | `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U10 → `agents.md` セクション4.4 |
| **U11** | 重要度付与・重複統合の規範 | `severity-ranking.md` の評価語マッピング・統合ルールに従う | `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U11 → `severity-ranking.md` |
| **U12** | 認証情報の取り扱い | 外部接続の認証情報取得は connector に委譲（connector が credentials-manager ストアを含む複数ソースから解決）・connector 接続時は credentials-manager を直接呼び出さない・保存は credentials-manager skill 経由・値そのものを表示しない | `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U12 |
| **U13** | 動的検証の SKIPPED 明示 | ビルド・Linter・テスト・CVE スキャンが未実施の場合は SKIPPED として記録（「問題なし」と書かない） | `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U13 → `output-format.md` セクション4 |
| **U14** | 提出コードの信頼性原則 | 提出コード内のパターンを規約として類推しない。類推が必要な場合はユーザー承認を義務化し、承認結果を state.yaml に記録 | `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U14 → `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/state/code-trustworthiness.md` |
| **U15** | 指摘への信頼度（Confidence）付与 | すべての指摘に信頼度 0〜100 を付与する。統合時の足切り・表示は `severity-ranking.md` セクション 7 に従う | `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U15 → `severity-ranking.md` セクション 7 |
| **U16** | 防御コード削除の回帰検出 | 差分の削除側で既存の防御コード（例外処理・入力検証・リソース解放・a11y 属性・認可・エラー表示 UI）が失われていれば回帰として指摘する | `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U16 |

---

## 3. Observation ルール（観点別レビュースキル共通・MANDATORY）

| ID | ルール | 達成基準 | 該当スキル |
|----|------|---------|----------|
| **O1** | 内部エージェントの並列起動 | 1 メッセージ内で全担当エージェントを並列起動する | impl / testing / security / architecture / frontend |
| **O2** | 中間レポートのフォーマット遵守 | 各 SKILL.md の「出力フォーマット」セクションに従って中間レポートを返す | impl / testing / security / architecture / frontend |
| **O3** | 動的検証の権限ガード | `linter-static-analysis` / `test-runner` / `dependency-safety` は対応する Bash 権限がある場合のみ実コマンド実行・なければ SKIPPED | impl / testing / security |
| **O4** | スコープ外観点の他スキル誘導 | 自スキルのスコープ外（例: テストレビューでセキュリティ）は対応スキルへ誘導 | impl / testing / security / architecture / frontend |
| **O5** | 指摘ごとのスコープ判定 | 指摘・改善提案には「スコープ内 / スコープ外」フラグを付与して返却 | impl / testing / security / architecture / frontend |
| **O6** | プロジェクト規約の最優先評価 | `CLAUDE.md` / `.claude/rules/` / 既存スタイルガイドを最優先評価基準とし、根拠に引用 | impl / testing / security / architecture / frontend |
| **O7** | 仕様整合性チェック（任意） | `spec_summary` 引数指定時のみ実装漏れ・仕様逸脱・仕様矛盾を追加観点として評価 | impl |
| **O8** | スキル単独実行時の進捗管理 | オーケストレーター不在で単独実行された場合、本スキル自身で `progress.md` を作成・維持 | impl / testing / security / architecture / frontend |
| **O9** | Finding ID 採番禁止 | 観点別スキル・エージェントは Finding ID（`CR-NNN`）を採番しない（採番はオーケストレーター責務） | impl / testing / security / architecture / frontend |
| **O10** | 言語別レビュー観点プロファイルの適用 | `language-profiles` 引数（未受領時は自己検出）に基づき、検出言語・FW の観点プロファイル（`languages/` / `frameworks/`）をエージェントプロンプトに含める。未対応言語は制約事項に明記 | impl / testing / security / architecture / frontend |

---

## 4. Coordinator ルール（オーケストレーター・MANDATORY）

| ID | ルール | 達成基準 | SSOT |
|----|------|---------|------|
| **C1** | モード選択 | Step 0 で AskUserQuestion により標準/簡易を確認（コマンド経由は固定）/ 非対話は標準既定 | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/flow/mode-selection.md` |
| **C2** | スコープ確定 | 比較ブランチは `origin/develop` → `main` → `master` 順で自動判定 | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/flow/scope-detection.md` |
| **C3** | 観点別スキル並列起動 | 動員観点別スキルを 1 メッセージ内で並列起動（Step 4） | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/flow/flow.md` Step 4 |
| **C4** | Agent Teams 採用判定 | 大規模 / セキュリティクリティカル / DB スキーマ等で 5 パターンから選定 + ユーザー承認 | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/flow/team-selection.md` |
| **C5** | 結果統合・重複排除 | 同一指摘は最も重い重要度を採用、Issues / Suggestions / **Scope-out** に三分類 | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/flow/flow.md` Step 5 |
| **C6** | Verdict 判定マトリクス | Critical/High/Medium 件数 × test-runner ステータスで Ready/Attention/Work を確定 | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/output/output-format.md` セクション3 |
| **C7** | 統合サマリの統一フォーマット | `template/review-summary.md` の **9 セクション + ヘッダブロック** 順序固定で出力。各 H2 セクションは `<details><summary>` 折り畳み + 内部 HTML 記法（タイトル行・ヘッダブロックは対象外）。セクション 1〜3 の `<summary>` には件数 + 状態記号（>0 は「⚠」 / 0 件は「✓ + 状態語」）を付記 | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/template/output/review-summary.md` |
| **C8** | スコープ外指摘の専用セクション | 「## 3. スコープ外指摘」に分離し、判断理由を必須記載 | `${CLAUDE_PLUGIN_ROOT}/references/scope-out-policy.md` セクション3 |
| **C9** | 未確認事項の明記 | ビルド / Linter / テスト / CVE スキャン / PR 差分取得 / 大規模絞り込みを「## 7. 未確認事項・制約」で明示 | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/output/output-format.md` セクション4 |
| **C10** | 集計セクション必須項目 | 実施日時・モード・参加観点別スキル・比較ブランチ・対象 head SHA・参照規約・件数集計を明記 | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/output/output-format.md` セクション1.4 |
| **C11** | プロジェクト規約読込 | Step 2 で `CLAUDE.md` / `.claude/rules/` / `.editorconfig` 等を読み込み 2,000 字要約を生成 | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/flow/flow.md` Step 2 |
| **C12** | Pr-review からの委譲のみ受領 | PR 識別子（URL/ID）を直接処理しない（循環参照防止） | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/SKILL.md` PR レビューとの関係 |
| **C13** | Finding ID の一括採番 | Step 6 で全指摘・改善提案・スコープ外指摘に `CR-NNN` 形式で一括採番（観点別スキル・エージェントは採番しない） | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/output/output-format.md` セクション1.5 / `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/flow/flow.md` Step 6 |
| **C14** | Finding ID の連続通番 | 統合サマリ全体で Issues → Suggestions → Scope-out の順に連続通番 | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/output/output-format.md` セクション1.5 |
| **C15** | Finding ID の見出し表示 | 各指摘の見出しが HTML 記法（`<h4>CR-NNN: <タイトル></h4>` 等の `<h3>`/`<h4>`）で、サマリー表の ID 列に Finding ID を含む | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/template/output/review-summary.md` |
| **C16** | 前回 state.yaml の読み込み | Step 0-P で `.claude/.local/plugins/deep-code-review/{branch}/` 配下の最新 state.yaml を読み込む（存在する場合）。`review_round` を +1 する | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/state/state-management.md` |
| **C17** | inputs フォルダの確認 | Step 0-P で inputs フォルダを確認し、未作成時はヒアリングまたはスキップ理由を記録する | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/state/inputs-management.md` |
| **C18** | state.yaml の生成・保存 | Step 8.5 で state.yaml を規定パスに生成し、全 finding に `detail_summary` を記述する | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/state/state-management.md` / `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/flow/flow.md` Step 8.5 |
| **C19** | PR Thread ID の記録 | PR レビュー時、投稿済み全 finding に `pr_thread_id` を state.yaml に記録する | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/flow/flow.md` Step 8.5-4 |
| **C20** | コード信頼性原則の遵守 | 提出コードのパターンを規約として無断類推しない（U14 のオーケストレーター適用） | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/state/code-trustworthiness.md` |
| **C21** | 解消状態の整合 | `remaining_issues` と `resolved_since_last` に同一 ID が存在しない | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/state/state-management.md` |
| **C22** | pr-review 委譲時の内部データ返却 | `pr-review` から委譲された場合、結果を対話文なしの内部データとして返却する | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/flow/flow.md` Step 8 |
| **C23** | 言語・FW 検出と観点プロファイル確定 | Step 2 で `language-detection.md` に従い言語・FW を検出し、適用プロファイル一覧を適用規約サマリに記録。Step 4 委譲引数 `language-profiles` で観点別スキルに、Step 4-T ではスポーンプロンプトの「検出言語・FW と適用観点プロファイル」欄でチームメンバーに引き渡す | `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` / `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/flow/flow.md` Step 2 |
| **C24** | 低信頼指摘の足切り | Step 5 統合時に信頼度 60 未満の指摘を Issues / Suggestions から除外し、除外件数を集計セクションに記録する | `${CLAUDE_PLUGIN_ROOT}/references/severity-ranking.md` セクション 7 |
| **C25** | プロファイルアンカー照合 | Step 5 三分の前に各 finding の重要度を適用プロファイルのセクション 4 アンカーと照合し、アンカー下限が Medium 以上の指摘を Suggestions に降格しない（下回っていれば Issues へ再配置） | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/flow/flow.md` Step 5 |

---

## 5. PR Adapter ルール（pr-review・MANDATORY）

| ID | ルール | 達成基準 | SSOT |
|----|------|---------|------|
| **P1** | PR 識別子のホワイトリスト正規表現バリデーション | ID 単体 / GitHub / Cloud ADO / TFS / visualstudio.com の 5 形式に厳密一致 | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/SKILL.md` Step 1 |
| **P2** | 認証情報の事前確認 | Step 1.5 でホスト別の認証情報を API 呼び出し前に確認 / 不足時はユーザー問い合わせ | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/credentials-precheck.md` |
| **P3** | TFS Server ホストの検証 | NETRC 書き込み前にホストが credentials.json のホワイトリストに含まれることを確認（NTLM relay 対策） | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/azure-devops-tfs-ntlm.md` セクション2 |
| **P4** | worktree 分離環境 | Step 5.5 で PR ブランチを worktree にチェックアウト、Step 7.5 でレビュー判定に応じて worktree を処理（OK: 削除、NG: 維持） | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/local-checkout-review.md` |
| **P5** | PR コメント投稿は既定で必須 | 標準/簡易レビュー共に PR への結果投稿（サマリースレッド + インライン）が必須 / 「コメント投稿不要」明示時のみスキップ | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/SKILL.md` 権限ポリシー |
| **P6** | コメント本文サニタイズ | XSS / トラッキング画像 / 危険スキームリンク / 機密文字列伏字化 | `${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` セクション3-4 |
| **P7** | 予約文字エスケープ | `#`/`@`/`!` 等の自動リンク化対象を `\#`/`\@`/`\!` でエスケープ or 明示リンク化 | `${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` セクション5.5 |
| **P8** | 投稿前チェックリスト通過 | サニタイズ / コード引用 / 投稿先指定の各チェックリスト全項目通過後に投稿 | `${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` セクション5.6 |
| **P9** | コード引用範囲の規範遵守 | コードフェンス必須 / 言語識別子明記 / 引用範囲と `start_line`/`line` の完全一致 | `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/output/output-format.md` セクション2.5 |
| **P10** | 自著限定 + auto-resolve 既定 | 他者起票スレッドへの reply / status 変更禁止 / 既定 auto-resolve。`auto-resolve=false` 指定時は dry-run | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/comment-status-policy.md` セクション0.1-0.2 |
| **P11** | （廃止・欠番） | キーワード除外は撤廃。経緯は comment-status-policy.md 改定注記参照 | — |
| **P12** | Bot 識別子付き返信 | resolve / fixed 変更時は connector の `marker:` で `[deep-code-review-plugin]` を指定した reply を必須 | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/comment-status-policy.md` セクション0.4 |
| **P13** | 解消判定アルゴリズム | コード修正系 / テスト追加系 / ドキュメント系の 3 系統で解消可否判定 | `${CLAUDE_PLUGIN_ROOT}/references/comment-resolution-judge.md` |
| **P14** | コマンドインジェクション対策 | コメント本文・ファイルパス・threadId 等は `jq --arg` / `--argjson` / `--rawfile` 経由で JSON body 構築 | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/comment-posting.md` セクション7.1-7.2 |
| **P15** | HTTP エラーハンドリング | 全 API 呼び出しは HTTP コード取得 + case 分岐（401-403 即停止 / 429 指数バックオフ / 5xx 単発リトライ） | `${CLAUDE_PLUGIN_ROOT}/references/http-error-handling.md` |
| **P16** | サマリースレッド統一フォーマット | `template/review-summary.md` のヘッダブロック + 9 セクション順序固定。各 H2 セクションは `<details><summary>` 折り畳み + 内部 HTML 記法。セクション 1〜3 の `<summary>` には件数 + 状態記号（>0 は「⚠」 / 0 件は「✓ + 状態語」）を付記 | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/comment-posting.md` セクション7.5 |
| **P17** | 旧サマリーの closed 化 | 新サマリー投稿時は旧サマリースレッドを `status=closed` に更新 | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/comment-posting.md` セクション7.5.5 |
| **P18** | 完了前チェックリスト全項目通過 | Step 7.5 で A〜D 全グループのチェックリストを通過させる | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/completion-checklist.md` |
| **P19** | 完了報告内容 | レビューモード / 件数 / 投稿件数 / 失敗件数 / 解消件数 / auto-resolve 状態（false 指定時のみ dry-run と明示） / チェックアウト状態 / 復元状態 / **PR 外操作なし宣言** | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/SKILL.md` Step 8 |
| **P20** | サマリースレッド Finding ID 目次 | サマリースレッドのヘッダブロック直後に Finding ID 一覧表を含める | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/comment-posting.md` セクション7.0.2 |
| **P21** | インラインコメント本文の Finding ID 表示 | 各インラインコメント本文の冒頭が `## [CR-NNN] [<致命度>] <タイトル>` の **H2 見出し形式** | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/comment-posting.md` セクション7.0.1 |
| **P22** | Finding ID とコメント ID の対応トレース | 完了報告に「Finding ID → 投稿コメント ID」の対応表を含める | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/SKILL.md` Step 8 |
| **P23** | Finding ID → Thread ID マッピング永続化 | Step 7.4 で finding-thread-map.json をセッション作業領域に保存 | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/scope-out-acknowledgment.md` セクション7 |
| **P24** | Pattern D（ユーザー指示スコープ外了承）の安全方針 | 自動判定禁止 / 自著限定 / 完了後の状態検証 | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/comment-status-policy.md` セクション0.5 + `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/scope-out-acknowledgment.md` セクション3 |
| **P25** | Pattern D の reply + status 更新 | 了承 reply 投稿 + status を `wontFix`（Azure）/ resolve（GitHub）に更新 | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/re-review-flow.md` セクション3 Pattern D + `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/scope-out-acknowledgment.md` セクション5 |
| **P26** | 最終状態（サマリーのみ active）の検証 | Step 9 完了後 / Step 7.5 完了前チェックで PR の active なインラインスレッドが残っていないことを検証 | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/scope-out-acknowledgment.md` セクション5 + `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/completion-checklist.md` B-1.7 |
| **P27** | 残スレッドの一覧と推奨アクション | 未対応スレッドが残る場合は完了報告に thread_id / file:line / 推奨アクションを含める | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/completion-checklist.md` B-1.7-3, B-1.7-4 |
| **P28** | Pattern E（修正完了確認）の発火 | ユーザー修正指示 + Claude による修正コミット作成が成立した時点で `ack-fixed=` 相当の処理を自律発火（reply 投稿 + status=fixed 化） | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/comment-status-policy.md` セクション 0.5.E + `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/scope-out-acknowledgment.md` セクション 8 |
| **P29** | Pattern E の修正コミット明示リンク必須 | reply 本文に `[<sha7>](<commit-url>)` 形式の修正コミットへのリンクを必ず含める | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/re-review-flow.md` セクション 3 Pattern E |
| **P30** | 修正完了後の状態放置禁止 | reply 投稿のみで status=active のまま放置することを禁止（必ず status=fixed まで更新） | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/comment-status-policy.md` セクション 0.5.E + `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/completion-checklist.md` B-1.8 |
| **P31** | サマリーの新規スレッド投稿必須 | サマリースレッドは毎回新規スレッドとして投稿し、既存サマリースレッドへの reply 投稿を行わない | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/comment-posting.md` セクション 7.5.0 |
| **P32** | サマリー投稿順序の厳守 | サマリー投稿はインラインコメント全件投稿後の最終ステップとし、旧サマリーの closed 化 → 新サマリーの新規 POST の順序を厳守する | `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/comment-posting.md` セクション 7.5.0 |

---

## 6. Inference Skill ルール（code-review-spec-inference・MANDATORY）

| ID | ルール | 達成基準 | SSOT |
|----|------|---------|------|
| **I1** | 情報源の優先順位 | 仕様書 > description 構造化見出し > 外部リンク > リポジトリ内資料 > 過去コメント > Bot 過去レビュー の順 | `${CLAUDE_PLUGIN_ROOT}/skills/code-review-spec-inference/references/expected-behavior.md` セクション1 |
| **I2** | 外部 fetch のホワイトリスト準拠 | `safe-external-fetch.md` のドメインホワイトリスト方式に厳密準拠 | `${CLAUDE_PLUGIN_ROOT}/references/safe-external-fetch.md` |
| **I3** | 取得結果のサニタイズ | `comment-sanitization.md` の規則を取得資料にも適用 | `${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` |
| **I4** | 矛盾事項の検出 | 複数情報源間の矛盾を出力 JSON `conflicts` フィールドに格納 | `${CLAUDE_PLUGIN_ROOT}/skills/code-review-spec-inference/SKILL.md` Step 5 |
| **I5** | 出力 JSON フォーマット遵守 | `expected_behavior_summary` / `requirements` / `acceptance_criteria` / `conflicts` / `sources_used` の 5 フィールド構造 | `${CLAUDE_PLUGIN_ROOT}/skills/code-review-spec-inference/SKILL.md` 出力 |

---

## 7. Environment Skill ルール（env-setup・MANDATORY）

| ID | ルール | 達成基準 | SSOT |
|----|------|---------|------|
| **E1** | 確認モード既定 | 明示指示なしの場合は存在確認のみ | `${CLAUDE_PLUGIN_ROOT}/skills/env-setup/SKILL.md` 実行モード判定 セクション1 |
| **E2** | インストール承認の取得 | インストール実行前に AskUserQuestion でユーザー承認 | `${CLAUDE_PLUGIN_ROOT}/skills/env-setup/SKILL.md` 実行フロー セクション4 |
| **E3** | 管理者権限の自動昇格禁止 | 管理者昇格が必要な場合はユーザーへの実行案内のみ（自動昇格しない） | `${CLAUDE_PLUGIN_ROOT}/skills/env-setup/SKILL.md` 実行モード判定 セクション2 |
| **E4** | インストール優先順位 | winget → ツール固有サブコマンド → MSI/EXE の順 | `${CLAUDE_PLUGIN_ROOT}/skills/env-setup/SKILL.md` 実行モード判定 セクション2 |
| **E5** | 個別スキルの独自インストール禁止 | 他スキルが個別に winget / npm install -g 等を呼ばない | `${CLAUDE_PLUGIN_ROOT}/skills/env-setup/SKILL.md` 禁止事項 |
| **E6** | 管理対象ツールカタログの維持 | 新ツール追加時は `${CLAUDE_PLUGIN_ROOT}/skills/env-setup/references/tools-catalog.md` を更新 | `${CLAUDE_PLUGIN_ROOT}/skills/env-setup/SKILL.md` 管理対象ツール一覧 |

---

## 8. スキル別ルール適用マトリクス

各スキルが満たすべきルール ID の集合。各スキルの `references/checklist.md` はこのマトリクスに従って自動生成可能。

| スキル | Universal | Observation | Coordinator | PR Adapter | Inference | Env |
|------|-----------|-------------|-------------|------------|-----------|-----|
| **code-review**（オーケストレーター） | U1〜U16 | — | C1〜C25 | — | — | — |
| **pr-review** | U1〜U16 | — | — | P1〜P32 | — | — |
| **code-review-implementation** | U1〜U16 | O1〜O10 | — | — | — | — |
| **code-review-testing** | U1〜U16 | O1〜O6, O8, O9, O10 | — | — | — | — |
| **code-review-security** | U1〜U16 | O1〜O6, O8, O9, O10 | — | — | — | — |
| **code-review-architecture** | U1〜U16 | O1, O2, O4, O5, O6, O8, O9, O10 | — | — | — | — |
| **code-review-frontend** | U1〜U16 | O1, O2, O4, O5, O6, O8, O9, O10 | — | — | — | — |
| **code-review-spec-inference** | U1〜U16 | — | — | — | I1〜I5 | — |
| **env-setup** | U1〜U16 | — | — | — | — | E1〜E6 |

> O3（動的検証の権限ガード）は対応エージェントを持つスキル（impl / testing / security）のみ。
> O7（仕様整合性チェック）は impl のみ。
> O10（言語プロファイル適用）の運用詳細は `common-references.md` セクション 4.5 を参照。
> U9（並列起動）/ U10（エージェント共通指示）/ U11（重要度付与・重複統合）は **レビューエージェントを起動するスキル**（観点別 5 スキル + オーケストレーター code-review + pr-review 経由）に適用。エージェントを起動しない **spec-inference / env-setup は実質対象外**（各スキルの `references/checklist.md` の「本スキル適用外」宣言と対応）。
> U13（動的検証の SKIPPED 明示）は **動的検証を伴うスキル**（観点別 impl / testing / security の動的検証エージェント経由 + env-setup のツールインストール）に適用。**spec-inference は対象外**（外部 fetch 推論のみで動的検証を行わない）。
> U15（信頼度付与）はレビュー指摘を生成するスキル・エージェントに適用（env-setup / spec-inference は指摘を生成しないため実質対象外だが、指摘を出す場合は適用）。
> U16（防御コード削除の回帰検出）は U15 と同様 **コード差分を評価するスキル・エージェント**（観点別 5 スキル + それらを統合する code-review + pr-review 経由）に適用。**env-setup / spec-inference はコード差分レビューを行わないため実質対象外**（差分を評価する場合のみ適用）。

---

## 9. 達成状況の確認方法

各スキルは自身の `references/checklist.md` に以下を記載する:

1. 該当ルール ID の列挙（本マトリクスから抜粋）
2. 各 ID の達成基準（簡略版）
3. 自動チェック可能なものは検出スクリプト例
4. 完了前に手動確認すべき項目

達成状況の確認タイミング:

| スキル | 確認タイミング |
|------|--------------|
| code-review（オーケストレーター） | Step 8 統合サマリ出力前 |
| pr-review | Step 7.5 完了前チェックリスト（既存） |
| 観点別スキル | 中間レポート返却前 |
| code-review-spec-inference | 出力 JSON 返却前 |
| env-setup | インストール完了報告前 |

---

## 10. 規範の改訂手順

新しいルールを追加する場合:

1. 本マトリクス（`skill-rules-matrix.md`）に ID を採番して追加
2. SSOT となる詳細ファイルを作成 or 更新
3. 該当スキルの `references/checklist.md` に ID を追記
4. 関係する `SKILL.md` の参照リストを更新

ルールを廃止する場合:

1. 該当 ID は **再利用しない**（廃番）
2. 本マトリクスで「DEPRECATED」と明記し、廃止理由を記載
3. 各スキルの `checklist.md` から ID を削除

---

## 11. 関連リファレンス

- `${CLAUDE_PLUGIN_ROOT}/references/agents.md` — エージェント選定・プロンプト構成
- `${CLAUDE_PLUGIN_ROOT}/references/severity-ranking.md` — 重要度付与・重複統合
- `${CLAUDE_PLUGIN_ROOT}/references/scope-out-policy.md` — 別 PR 推奨禁止 / PR 外への影響禁止
- `${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` — コメント本文サニタイズ・予約文字エスケープ
- `${CLAUDE_PLUGIN_ROOT}/references/comment-resolution-judge.md` — 解消判定アルゴリズム
- `${CLAUDE_PLUGIN_ROOT}/references/safe-external-fetch.md` — 外部 fetch 安全方針
- `${CLAUDE_PLUGIN_ROOT}/references/http-error-handling.md` — HTTP エラー分岐・レート制限
