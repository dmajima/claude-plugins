# Case 15: progress.md 不在時のフォールバック atime

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "古い作業フォルダを整理して" |
| 引数 | `--days 30 --dry-run` |
| フラグ | `--dry-run` |
| 既存状態 | `.claude/.local/work/` 配下に以下が混在<br>- `20260401_01_with_progress/`（`progress.md` あり、mtime = 60 日前）<br>- `20260401_02_no_progress/`（`progress.md` 不在、配下ファイル mtime = 60 日前） |

## 期待動作

### Phase 1: 対象収集
- 両方のセッションを列挙、バリデーション合格

### Phase 2: atime 解決
- `20260401_01_with_progress/`: `progress.md` 存在 → `lastAccess = progress.md の mtime`
- `20260401_02_no_progress/`: `progress.md` 不在 → **フォールバック** で `lastAccess = セッションフォルダの mtime` + 配下最大 mtime
- 両方とも 60 日前なので、`--days 30` 閾値より古いと判定

### Phase 3: 候補表示
- 両セッションが候補に追加（2 件）
- `LastWrite` 列にはそれぞれ解決した atime が表示される

### Phase 4: ドライラン終了
- 実削除なし、exit 0

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし |
| 削除実行 | なし |
| 標準出力（要約） | 「候補件数: 2 件」+ 両セッションがリストアップ |
| 終了状態 | 成功（exit 0）|

## 分岐の根拠

このケースが分岐するトリガーは `progress.md` ファイルの有無 である:

- 有: `(Get-Item progress.md).LastWriteTimeUtc` を採用
- 無: フォールバック経路（セッション + 配下最大 mtime）

## atime 戦略の設計意図

- Claude Code セッション運用と整合（`progress.md` がアクティブ運用の指標）
- NTFS atime（Windows 既定無効）に依存しない
- 旧セッション（progress.md 規約導入前）にもフォールバックで対応

## 関連ケース

- `case-09_active_session.md`（進行中保護: `progress.md` mtime が 5 分以内）
- `case-13_config_show.md`（`atime_strategy` フィールドの確認）
