#!/usr/bin/env bash
# project-harness: SessionStart 鮮度検知フック
#
# .claude/references/.sync-state.json の last_synced_commit と HEAD の乖離コミット数を数え、
# threshold_commits（既定 10）以上の場合のみ stdout（additionalContext）で
# /project-harness:update の実行推奨を通知する。
#
# 設計原則（sync-spec.md 節 3）:
# - フェイルオープン: いかなる失敗でも exit 0 で素通りし、セッション開始をブロックしない
# - 無干渉: ハーネス未導入プロジェクト（.sync-state.json なし）では一切出力しない
# - 軽量: 外部依存なし（git + 標準コマンドのみ。jq はあれば使用）

set -u

# 1) git リポジトリ確認（非リポジトリなら無出力終了）
repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$repo_root" ] || exit 0

# 2) sync-state 存在確認（ハーネス未導入なら無干渉）
state_file="$repo_root/.claude/references/.sync-state.json"
[ -f "$state_file" ] || exit 0

# 3) state 読み出し（jq 優先、なければ sed フォールバック）
last_synced=""
threshold=""
if command -v jq >/dev/null 2>&1; then
    last_synced=$(jq -r '.last_synced_commit // empty' "$state_file" 2>/dev/null) || last_synced=""
    threshold=$(jq -r '.threshold_commits // empty' "$state_file" 2>/dev/null) || threshold=""
else
    last_synced=$(sed -n 's/.*"last_synced_commit"[[:space:]]*:[[:space:]]*"\([0-9a-fA-F]\{7,40\}\)".*/\1/p' "$state_file" 2>/dev/null | head -n 1)
    threshold=$(sed -n 's/.*"threshold_commits"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$state_file" 2>/dev/null | head -n 1)
fi
[ -n "$last_synced" ] || exit 0
case "$threshold" in
    ''|*[!0-9]*) threshold=10 ;;
esac

# 4) SHA 到達可能性（rebase 等で不能な場合は harness-update 実行時に扱うため無出力）
git -C "$repo_root" cat-file -e "${last_synced}^{commit}" 2>/dev/null || exit 0

# 5) 乖離コミット数の取得
drift=$(git -C "$repo_root" rev-list --count "${last_synced}..HEAD" 2>/dev/null) || exit 0
case "$drift" in
    ''|*[!0-9]*) exit 0 ;;
esac

# 6) 閾値判定（超過時のみ additionalContext を出力）
if [ "$drift" -ge "$threshold" ]; then
    printf '%s\n' "[project-harness] .claude ハーネスの最終同期から ${drift} コミット進行しています（閾値 ${threshold}）。仕様・設計ドキュメントが実装と乖離している可能性があるため、/project-harness:update の実行を推奨します。閾値は .claude/references/.sync-state.json の threshold_commits で調整できます。"
fi

exit 0
