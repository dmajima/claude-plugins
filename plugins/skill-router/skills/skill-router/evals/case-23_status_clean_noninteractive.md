# case-23 router-status --clean noninteractive

`/router-status --clean` で 30 日超のセッションフォルダを非対話的に削除する正例。`router-status.md` の引数モード分岐 (`--clean`) のうち、破壊的副作用を持つブランチを独立検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | `/router-status --clean` |
| 既存状態 | `<base>/sessions/` 配下に複数セッションフォルダが存在し、うち `mtime` が現時刻から 30 日以上前のものが N 件含まれる |
| モード | 非対話（コマンド実行・引数完全指定）|

## トリガープロンプト

```text
/router-status --clean
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | `--clean` 引数を確定済みとして検出（`AskUserQuestion` を発行しない） |
| 2 | `references/scripts/commands/resolve_base.sh` で `<base>` を解決 |
| 3 | `references/scripts/commands/clean_old_sessions.py "<base>"` を Bash 経由で起動 |
| 4 | `<base>/sessions/*/` を走査し `time.time - st_mtime > 2592000` (30 日) のディレクトリを `shutil.rmtree(ignore_errors=True)` で削除 |
| 5 | 標準出力に `clean_old_sessions: removed N session(s) older than 30 days` を 1 行出力 |
| 6 | 削除完了後、通常の `/router-status` フロー (統計・直近決定・スコア分布) に進む |

## 期待出力

| 出力 | 内容 |
|-----|------|
| stdout | `clean_old_sessions: removed N session(s) older than 30 days` (1 行) |
| 副作用 | `<base>/sessions/<sid>/` (30 日超) のディレクトリツリーを削除 |
| 副作用 (制約) | 30 日以内のセッション・ファイル・他ディレクトリは削除しない |
| 失敗時 | rmtree が失敗した場合は `ignore_errors=True` で継続、削除件数のみ提示 |
| 後続動作 | `/router-status` 通常表示 (`stats.skills_indexed` / `recent decisions` 等) |

## 分岐の根拠

`commands/router-status.md` の動作モード表で `--clean` がクリーンアップモードとして定義され、`references/scripts/commands/clean_old_sessions.py` に実装が分離されている (ADR-025 準拠)。30 日超セッション削除は破壊的副作用のため、`/router-status` 統計表示モード (case-02) と独立してケース化することで eval-guide.md「主要分岐の各ブランチを 1 ケース以上カバー」要件を満たす。

## 関連ケース

- `case-02_status` — 引数なし時の統計表示フロー (非破壊的)
- `case-09_non_interactive` — `/router-toggle off` 等、別の非対話コマンドモード
- `case-17_router_embedding_cache_clear_noninteractive` — `/router-embedding-cache --clear` の同様の非対話破壊的モード

## 備考

- 検証手順: `<base>/sessions/<old-sid>/` を `os.utime` で 31 日前 mtime にしてから `/router-status --clean` を実行し、`<old-sid>/` ディレクトリの不在を確認
- 実装は標準ライブラリのみ (`shutil` / `time` / `pathlib`)、fastembed 等の追加依存なし
- べき等: 削除対象がなくても `removed 0 session(s)` を出力して exit 0
- 30 日の閾値は `clean_old_sessions.py` の `_AGE_THRESHOLD_SECONDS = 30 * 24 * 60 * 60` 定数で管理
