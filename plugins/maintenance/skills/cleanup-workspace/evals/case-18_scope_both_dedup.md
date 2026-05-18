# Case 18: --scope both で global/project が同一パスを指す場合の重複排除

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "両方のスコープで古いセッションを整理（リポジトリがホーム直下）" |
| 引数 | `--scope both --days 30 --dry-run` |
| フラグ | `--dry-run` |
| 既存状態 | 現在のリポジトリルートがユーザホーム配下（例: `~/myrepo`、または extreme には `~/` 自身）の場合、`~/.claude/.local/work/` と `<repo>/.claude/.local/work/` が同一物理パスに解決される環境 |

## 期待動作

### Phase 1: 引数解析
- `--scope both`、`--days 30`、`--dry-run`

### Phase 2: 対象ルート列挙
- グローバル: `~/.claude/.local/work/` を Resolve-Path で正規化
- プロジェクト: `git rev-parse --show-toplevel` でリポジトリルートを取得し、`<root>/.claude/.local/work/` を Resolve-Path で正規化
- procedures.md 1.1 に従い **同一パスは重複除外**

### Phase 3: セッション列挙
- 重複除去後の単一ルートからセッションを 1 回だけ列挙
- 同一セッションを **2 重に削除候補に追加しない**

### Phase 4: 候補表示
- 候補件数は重複なし
- 「===== クリーンアップ候補 =====」「scope: both」を出力

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 重複セッション | なし（同一物理パスのセッションが 2 回出てこない） |
| Phase 2 ログ | "対象ルート 1 件（global / project 重複検出）" 等の通知 |
| 終了状態 | exit 0 |

## 設計意図

`--scope both` の通常運用では global と project は異なる場所を指すが、ホーム直下にリポジトリを
作成した特殊環境では同一パスに解決されうる。`Test-ValidSessionPath` 通過後に同一フォルダが
2 回削除候補に挙がると、2 回目の `Remove-Item` で「既に削除済み」エラーが `$failed` に
記録される副作用を持つ。本ケースはこの副作用を防ぐ重複排除ロジックを回帰テストとして固定する。

## 関連ケース

- `case-01_dry_run.md`（通常の scope=both 既定）
- `case-05_scope_global.md`（global のみ）
- `case-17_scope_project.md`（project のみ）
- procedures.md 1.1 重複除外仕様
