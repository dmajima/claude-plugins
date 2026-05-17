# Evals: sync-settings

このディレクトリは `sync-settings` スキルの動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| case-01 | 初回ドライランで差分表示のみ | `--dry-run` 指定 + 初回 |
| case-02 | 対話モード + overwrite で同期承認 | 既定戦略 + AskUserQuestion で「同期する」 |
| case-03 | 対話モード + キャンセル | AskUserQuestion で「キャンセル」 |
| case-04 | 非対話モード (--yes) | `--yes` 指定 |
| case-05 | merge 戦略で settings.json をマージ | `--strategy merge` 指定 |
| case-06 | skip 戦略で既存保持 | `--strategy skip` 指定 |
| case-07 | `--prune` でローカルのみのファイル削除 | `--prune` + overwrite 戦略 |
| case-08 | 認証情報自動除外 | リモートに `credentials.json` が含まれていても除外 |
| case-09 | 設定ファイル再利用 | 2 回目以降、`sync-config.json` から既定値取得 |
| case-10 | `--no-backup` でバックアップなし | `--no-backup` 指定（警告ログ出力） |
| case-11 | バックアップ取得失敗時の中止 | バックアップディレクトリ作成 / コピー失敗（fail-closed） |
| case-12 | ブランチ不在エラー | Git CLI `$LASTEXITCODE != 0` |
| case-13 | `/sync-map-set` 対話モード（3 質問同時発火） | `$ARGUMENTS` 空・project スコープ既定 |
| case-14 | `/sync-map-set` 非対話モード（バリデーション含む） | `$ARGUMENTS` 非空 |
| case-15 | `/sync-map-list` 一覧表示 | `--show` 有無で list/show 分岐 |
| case-16 | `/sync-map-delete` 対話モード（2 段階確認） | `$ARGUMENTS` 空・誤削除防止 |
| case-17 | `/sync-pull --strategy interactive`（差分 1 件ずつ AskUserQuestion） | `--strategy interactive` 指定・差分件数で分岐（少数 1〜5 / 大量 6+）|
| case-18 | `/sync-push` 基本動作（dry-run + 対話モード） | sync-push.ps1・マッピング解決→fetch+reset→ローカル→repo/ コピー→git add/commit/push |
| case-19 | `--dry-run` と `--yes` 同時指定（dry-run 優先） | safety.md 6.2: 両フラグ同時指定時に dry-run を採用し warning 出力 |
| case-20 | 非対話モードで Repo / Mapping 不足エラー | `--yes` 指定 + Repo 取得不能（即時 exit 1） |
| case-21 | 不正 URL / Branch 名のバリデーション失敗（4 sub-case） | REPO_URL_REGEX / BRANCH_REGEX 違反 / マッピング由来値の再検証 |
| case-22 | `/sync-push` の `--Yes` なし時の安全停止 | --Yes 未指定 + 差分あり → push 実行せず exit 0 |
| case-23 | `/sync-push` PR 作成失敗時のロールバック / 手動案内 | gh CLI 存在 + 認証エラー等で `gh pr create` 失敗 → warning + 手動案内（リモートブランチは残置）|

## 実行確認方法

各ケースの「入力」セクションのフレーズで Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。実機検証時は `--dry-run` を必ず併用して安全に確認する。

## ケース追加ルール

新しい分岐ロジック（新引数・新戦略・新エラー系等）を追加した時は、対応するケースファイルを必ず追加する。各ケースは「入力 / 期待動作 / 期待出力 / 分岐の根拠 / 関連ケース」の構造で記述する。
