# プラグイン共通 references（人間向けインデックス）

`deep-code-review` プラグインの全スキルが共通参照する SSOT 規範群のディレクトリです。
本ファイルは **人間（利用者・開発者）向けのインデックス** であり、Claude エージェントの動作では参照されません。

## ファイル一覧

| ファイル | 内容 |
|---------|------|
| `CLAUDE.md` | Claude エージェント向けの原則・タスク駆動ナビゲーション（AI が最初に読む） |
| `skill-rules-matrix.md` | 全スキル横断のルール ID 体系（U / O / C / P / I / E 系）と適用範囲の SSOT |
| `universal-rules.md` | Universal ルール U1〜U16 の規範本文・達成基準 |
| `agents.md` | レビューエージェントの選定基準とプロンプト構成 |
| `severity-ranking.md` | 指摘の重要度付与基準・重複統合ルール・信頼度（0〜100）による足切り |
| `language-detection.md` | レビュー対象差分からの言語・FW 検出手順と観点プロファイル対応表 |
| `conventions-resolution.md` | レビュー基準（規約）の 5 段階優先順位解決（プロジェクト規約 > デファクト） |
| `languages/` | 言語別レビュー観点プロファイル（C# / Python / JavaScript / TypeScript / HTML / CSS / PHP / SQL の 8 言語。読み込みガイドは `languages/CLAUDE.md`） |
| `frameworks/` | FW 別レビュー観点プロファイル（dotnet / php-web / python-web / node / react / vue / frontend-tooling / orm の 8 ファイル） |
| `scope-out-policy.md` | スコープ外指摘の扱い・「別 PR 推奨」等の禁止文言 |
| `comment-sanitization.md` | コメント本文のサニタイズ・機密文字列伏字化・予約文字エスケープ |
| `comment-resolution-judge.md` | 既存レビュースレッドの解消判定アルゴリズム（ホスト非依存） |
| `http-error-handling.md` | REST API 呼び出しの HTTP ステータス分岐・エラー処理 |
| `safe-external-fetch.md` | 外部 URL 取得の安全方針（SSRF 対策・ドメインホワイトリスト） |
| `common-references.md` | 観点別 5 スキルが共通参照するリファレンスのインデックス |
| `roadmap.md` | 将来計画・共通化昇格基準・リリース判定ルール（履歴は Git 管理） |

## 設計方針（人間向けの要点）

- ここに置く規範は **複数スキルから参照される横断的関心事**（Cross-Cutting Concern）に限る。昇格判定基準は `roadmap.md` セクション 3 を参照
- 規範の改訂は `skill-rules-matrix.md` を起点に行い、各スキルの `references/checklist.md` へ同期する（SSOT 運用）
- ファイルを追加・改名した場合は本ファイルと `CLAUDE.md` のナビゲーション表を更新する

## 編集時の注意

- 共通 references から個別スキル固有のロジックへ依存を持ち込まない（詳細な参照方向の原則は各規範ファイル冒頭の「位置付け」を参照）
- 規範ファイルは 1 ファイル 1 関心事で管理し、肥大化したら分割を検討する
