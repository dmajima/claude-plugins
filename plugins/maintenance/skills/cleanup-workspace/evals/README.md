# Evals: cleanup-workspace

このディレクトリは `cleanup-workspace` スキルの動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| case-01 | ドライランで候補表示のみ | `--dry-run` 指定 |
| case-02 | 対話モードで削除承認 | 既定モード + AskUserQuestion で「削除する」選択 |
| case-03 | 対話モードでキャンセル | 既定モード + AskUserQuestion で「キャンセル」選択 |
| case-04 | 非対話モードで自動削除 | `--yes` / `--non-interactive` 指定 |
| case-05 | スコープ別（global のみ） | `--scope global` 指定 |
| case-06 | keep-recent で最新 N 件保持 | `--keep-recent 3` 指定 |
| case-07 | 削除対象 0 件 | 全セッションが閾値内・新しい |
| case-08 | バリデーション失敗（不正パス検出） | 不正な名前のディレクトリが混在 |
| case-09 | 進行中セッション保護 | `progress.md` の mtime が 5 分以内 |
| case-10 | `--include-tmp` で tmp 追加削除 | `--include-tmp` 指定 |
| case-11 | `--dry-run` と `--yes` 同時指定（dry-run 優先） | 両フラグ同時指定 |
| case-12 | シンボリックリンク検出時のスキップ | `$item.LinkType` 非 `$null` |
| case-13 | 閾値設定の表示（`/cleanup-config`） | 引数なし or `--show` |
| case-14 | 閾値設定の変更（`/cleanup-config --set-days N` 等） | `--set-*` フラグ指定 |
| case-15 | progress.md 不在時のフォールバック atime | `progress.md` の有無で atime 解決経路が分岐 |
| case-16 | `/cleanup-config` 対話モード（引数なし・4 質問同時発火） | `$ARGUMENTS` が空 → AskUserQuestion 1 回で 4 質問同時 |

## 実行確認方法

各ケースの「入力」セクションのフレーズで Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。実機検証時は `--dry-run` を必ず併用して安全に確認する。

## ケース追加ルール

新しい分岐ロジック（新引数・新安全装置・新エラー系等）を追加した時は、対応するケースファイルを必ず追加する。各ケースは「入力 / 期待動作 / 期待出力 / 分岐の根拠 / 関連ケース」の構造で記述する。
