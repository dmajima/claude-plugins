# case-21 C2 比較ブランチ自動判定のフォールバック実演（origin/develop 不在 → main → master）

`origin/develop` が存在しないリポジトリで、比較ブランチを `main`（さらに無ければ `master`、すべて無ければリモート HEAD）へフォールバックして確定する**分岐の実演**を検証する。case-01/04 が「develop → main → master 順で自動判定する」という前提描写にとどまるのに対し、本ケースは develop 不在時に実際に採用ブランチが切り替わる過程を見る。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "このブランチをコードレビューして"（カレントは feature ブランチ。リモートに `origin/develop` は存在せず `origin/main` は存在。CLAUDE.md 等に比較ブランチ指定なし） |
| モード | 標準 |

## 分岐の根拠

`${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` C2「スコープ確定（比較ブランチは `origin/develop` → `main` → `master` 順で自動判定）」（SSOT: `${CLAUDE_SKILL_DIR}/references/flow/scope-detection.md` セクション 1.2「比較ブランチ自動判定の手順」）。同手順の「`git show-ref --verify refs/remotes/origin/${branch}` で develop → main → master を順に存在確認し、最初に存在したものを `DIFF_BASE` に採用。すべて無ければ `origin/HEAD` の symbolic-ref にフォールバック」・「採用した比較ブランチを必ずユーザーに通知」・「プロジェクト規約に指定があれば最優先」に基づく。前提描写ではなく、develop 不在で候補が繰り上がる過程が分岐の要点。

## 期待動作

- Step 1: `git fetch origin --prune` でリモート最新を取得してから比較ブランチ候補の存在確認を行う（未 fetch なローカルブランチによる誤判定の防止・scope-detection.md セクション 1.2）
- Step 1: `refs/remotes/origin/develop` を確認し**存在しない**ため候補から外す
- Step 1: 次に `refs/remotes/origin/main` を確認し**存在する**ため `DIFF_BASE=origin/main` を採用する（develop → main の繰り上がり）
- Step 1: 仮に main も無ければ master を、develop・main・master すべて無ければ `git symbolic-ref --short refs/remotes/origin/HEAD` のリモート既定ブランチにフォールバックする判定順序である（本ケースでは main 採用で確定）
- Step 1: 採用した比較ブランチ（`origin/main`）と、develop 不在のため繰り上げ採用した旨をユーザーに通知する（scope-detection.md「ユーザー通知（必須）」）
- Step 1: `git diff origin/main...HEAD` を差分取得コマンドとして用いる
- CLAUDE.md / .claude/rules/ に比較ブランチ指定がある場合は自動判定より優先されるが、本ケースでは指定がないため自動判定を採用する（scope-detection.md「プロジェクト固有の上書き」）
- Step 8: 集計セクションの「比較ブランチ」に `origin/main`（自動判定・develop 不在によるフォールバック）を記録する（output-format.md セクション 1.4）
- （以下は検出してはならない誤り）
    - develop が無い時点で自動判定を諦め、未 fetch のローカルブランチや直近コミットを無条件に対象化する
    - フォールバックで採用した比較ブランチをユーザーに通知しない

## 関連ケース

- case-01: 標準モード初回レビュー（比較ブランチ自動判定を前提として描写する側）
- case-04: 自然言語フレーズでのトリガー起動（スコープ未指定時の既定対象・自動判定の前提描写）
