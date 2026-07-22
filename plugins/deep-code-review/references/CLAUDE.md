# references/ 読み込みガイド（プラグイン共通）

## 目的と範囲

`deep-code-review` プラグインの全スキル（オーケストレーター `code-review` / 観点別 5 スキル / `pr-review` / `env-setup` / `code-review-spec-inference`）が共通参照する **SSOT 規範群** を管理する。
ルール ID 体系・サニタイズ・重要度基準・スコープ外方針・HTTP エラー処理・外部 fetch 安全方針・解消判定・**言語/FW 別レビュー観点（8 言語 + 主要 FW）・言語検出・規約優先順位解決**・ロードマップを集約する。

## 原則

- ルール ID（U / O / C / P / I / E 系）の SSOT は `skill-rules-matrix.md`。規範の追加・改廃は必ず matrix を起点に行い、各スキルの `references/checklist.md` へ同期する
- evals は全スキル統一で「入力 / 分岐の根拠 / 期待動作 / 関連ケース」の 4 セクション構成を採用する（extension-toolkit `eval-guide.md` の 5 セクション標準に対する本プラグインの明示的な簡略フォーマット。「期待出力」は期待動作の箇条書きに統合して記載する）。この簡略様式は `eval-guide.md` 節 3.1「大規模 eval スイートの簡略様式（条件付き許容）」に依拠する（本プラグインの evals は 9 スキル計約 129 ケースの大規模スイート＝同節の 50 件超の規模要件を満たし、簡略化の意図を本項で・5 セクション標準への段階移行方針を `roadmap.md` セクション 2 で明文化する条件下で「期待出力」表の省略が許容される）。新規ケースは既存最大番号 +1 から採番する
- Universal ルール（U1〜U16）の規範本文・達成基準は `universal-rules.md` が SSOT。改訂時は全スキル checklist との同期検証（grep 件数一致）を必須とする
- 共通 references は個別スキルのロジック・規範本体に依存しない（規範の依存方向は個別スキル → 共通の一方向。共通側が適用先スキルを示すポインタ・適用一覧の記載は許容）
- PR コメント投稿・外部資料転載の前には `comment-sanitization.md` のサニタイズ・機密伏字化・予約文字エスケープを必ず適用する
- 外部 URL の取得は `safe-external-fetch.md` のドメインホワイトリスト方式に厳密準拠する（SSRF 対策）
- 指摘の重要度は `severity-ranking.md` の基準で付与し、「別 PR 推奨」「Issue 起票」等の禁止文言は `scope-out-policy.md` に従って排除する
- 個別スキル references からの共通化昇格は `roadmap.md` セクション 3 の判定基準を満たす場合のみ実施する
- 本ディレクトリへのファイル追加・改名時は本ファイルのナビゲーション表を同期する

## ナビゲーション

| タスク | 参照先 |
|-------|-------|
| ルール ID 体系・スキル別適用範囲の確認 | `skill-rules-matrix.md` |
| Universal ルール（U1〜U16）の規範本文・達成基準 | `universal-rules.md` |
| レビューエージェントの選定・プロンプト構成 | `agents.md` |
| 指摘の重要度付与・重複統合・**信頼度足切り** | `severity-ranking.md` |
| **対象の言語・FW を検出し観点プロファイルを確定する** | `language-detection.md` |
| **レビュー基準（規約）の優先順位を解決する** | `conventions-resolution.md` |
| **言語別レビュー観点（8 言語）を参照する** | `languages/CLAUDE.md` → `languages/*.md` |
| **FW 別レビュー観点（.NET / Node / React / Vue / PHP Web / Python Web / FE ツール / ORM）を参照する** | `frameworks/CLAUDE.md` → `frameworks/*.md` |
| スコープ外指摘の扱い・禁止文言 | `scope-out-policy.md` |
| コメントのサニタイズ / 機密伏字化 / 予約文字エスケープ | `comment-sanitization.md` |
| 既存レビュースレッドの解消判定（Pattern A/C/D/E） | `comment-resolution-judge.md` |
| REST API の HTTP エラー分岐 | `http-error-handling.md` |
| 外部リンクの安全な取得（SSRF 対策・ホワイトリスト） | `safe-external-fetch.md` |
| 観点別 5 スキルの共通参照インデックス | `common-references.md` |
| コマンド（quick/standard）の共通動作定義 | `command-common-behavior.md` |
| バージョン履歴・計画・共通化昇格基準・リリース判定 | `roadmap.md` |

## 禁止事項

- プラグイン直下・スキル直下の `README.md`（人間向け）をエージェント動作で参照すること
- 共通 references に個別スキル固有ロジックへの依存を追加すること（適用先スキルを示すポインタ記載は除く）
- `skill-rules-matrix.md` を更新せずに各スキルの checklist だけを変更すること（SSOT 違反）
- ロードマップをプラグイン直下に再配置すること（プラグイン直下は許可リスト運用のため `references/roadmap.md` に固定）
