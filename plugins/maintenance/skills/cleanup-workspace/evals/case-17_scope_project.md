# Case 17: --scope project（プロジェクトのみ・非リポジトリ対応含む）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "このプロジェクトの古いセッションフォルダだけ整理して" |
| 引数 | `--scope project --days 30 --dry-run` |
| フラグ | `--dry-run` |
| 既存状態 | グローバル / プロジェクト双方に古いセッションフォルダ。カレントディレクトリは Git リポジトリ |

## 期待動作

### Phase 1: 引数解析
- `--scope project` を解析
- `--days 30 --dry-run` を解析

### Phase 2: 対象収集（プロジェクトのみ）
- `git rev-parse --show-toplevel` でリポジトリルートを取得
- `<repo_root>/.claude/.local/work/` のみを対象に列挙
- **グローバル `~/.claude/.local/work/` は走査しない**

### Phase 2 サブケース: 非リポジトリ環境
- `git rev-parse --show-toplevel` が失敗（カレントディレクトリが Git リポジトリ外）
- フォールバックとして現在のディレクトリの `.claude/.local/work/` を対象に試みる
- 該当ディレクトリが存在しない場合は「対象ルートが見つかりませんでした（スコープ: project）」と
  出力して exit 0（エラー扱いはしない）

### Phase 3: 古さ判定 + 進行中保護
- progress.md ベース atime + フォールバック mtime（既存ロジック）

### Phase 4: 候補表示
- 候補件数 0 または N
- 「(dry-run) 実削除は行いません」

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| グローバル走査 | なし |
| プロジェクト走査 | あり（リポジトリの場合）/ なし（非リポジトリの場合） |
| 標準出力 | "scope: project" を明示 |
| 終了状態 | exit 0 |

## 分岐の根拠

このケースが分岐するトリガーは `--scope project` 指定（`both` でも `global` でもない）である。

## エッジケース

| ケース | 期待挙動 |
|-------|---------|
| 非リポジトリ環境 | カレントの `.claude/.local/work/` を試みる。不在ならクリーンに exit 0 |
| プロジェクト直下に `.claude/.local/work/` なし | 「対象ルートが見つかりませんでした」 + exit 0 |
| グローバル側にだけ古いセッションあり | プロジェクト走査のみなので候補 0 件として終了 |

## 関連ケース

- `case-05_scope_global.md`（global のみ）
- `case-01_dry_run.md`（scope=both 既定 + dry-run）
