# case-29 比較ブランチ自動判定の最終フォールバック（develop/main/master 全不在 → origin/HEAD）（C2）

`origin/develop`・`origin/main`・`origin/master` がいずれも存在しないリポジトリ（例: `trunk` をデフォルトブランチとする）で、比較ブランチを `origin/HEAD`（リモート既定ブランチ）へフォールバックして確定する最終段を検証する。develop 不在 → main 採用で確定する case-21 が到達しない、候補が全て繰り上がった先の分岐。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "このブランチをコードレビューして"（カレントは feature ブランチ。リモートに `origin/develop`・`origin/main`・`origin/master` がいずれも存在せず、`origin/HEAD` は `origin/trunk` を指す。CLAUDE.md 等に比較ブランチ指定なし） |
| モード | 標準 |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/flow/scope-detection.md` セクション1.2「比較ブランチ自動判定の手順」（手順2: `git show-ref --verify refs/remotes/origin/${branch}` で develop → main → master を順に存在確認 / 手順3: すべて無ければ `git symbolic-ref --short refs/remotes/origin/HEAD` のリモート既定ブランチにフォールバック）・「ユーザー通知（必須）」・「既定ブランチ判定」、skill-rules-matrix.md C2。case-21（develop 不在 → main 採用の中間段）が到達しない最終段が本ケースの要点。

## 期待動作

- Step 1: `git fetch origin --prune` でリモート最新を取得してから比較ブランチ候補の存在確認を行う（scope-detection.md セクション1.2 手順1）
- Step 1: develop → main → master の順に `refs/remotes/origin/<branch>` を存在確認し、**いずれも存在しない**ため for ループで `DIFF_BASE` が未設定のまま抜ける（手順2）
- Step 1: 手順3のフォールバックとして `git symbolic-ref --short refs/remotes/origin/HEAD` を実行し、リポジトリのデフォルトブランチ（`origin/trunk`）を `DIFF_BASE` に採用する
- Step 1: 採用した比較ブランチ（`origin/trunk`）と、develop/main/master が全不在のため `origin/HEAD` にフォールバックした旨をユーザーに通知する（「ユーザー通知（必須）」）
- Step 1: `git diff origin/trunk...HEAD` を差分取得コマンドとして用いる
- 対照（別分岐）: `origin/HEAD` も未設定で既定ブランチが決まらない場合は、優先度2で確定せず優先度3以降（staged / unstaged / 直近コミット差分）に降りる（scope-detection.md セクション1.3〜1.5）
- CLAUDE.md / .claude/rules/ に比較ブランチ指定がある場合は自動判定より最優先だが、本ケースでは指定がないため自動判定を採用する（「プロジェクト固有の上書き」）
- Step 8: 集計セクションの「比較ブランチ」に `origin/trunk`（自動判定・develop/main/master 全不在による `origin/HEAD` フォールバック）を記録する（output-format.md セクション1.4）
- （以下は検出してはならない誤り）
    - develop/main/master 不在の時点で自動判定を諦め、未 fetch のローカルブランチや直近コミットを無条件に対象化する
    - `origin/HEAD` フォールバックで採用した比較ブランチをユーザーに通知しない
    - `trunk` 等の非標準デフォルトブランチを認識せず `main` / `master` を無理に仮定して差分を取る

## 関連ケース

- case-21: develop 不在 → main 採用（同じ C2 自動判定の中間段。本ケースは全不在の最終段）
- case-01: 標準モード初回レビュー（比較ブランチ自動判定を前提描写する側）
