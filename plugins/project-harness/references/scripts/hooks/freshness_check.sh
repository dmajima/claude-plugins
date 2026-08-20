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
# - 値を信頼しない: state ファイルは対象リポジトリの管理下にあるため、形式検証を経てから使う
#
# 診断: 環境変数 PROJECT_HARNESS_DEBUG を非空にすると、どのステップで終了したかを stderr へ出力する。

set -u

debug() {
    [ -n "${PROJECT_HARNESS_DEBUG:-}" ] && printf '[project-harness/freshness] %s\n' "$1" >&2
    return 0
}

# 1) リポジトリルートの解決（フックの cwd を信頼せず CLAUDE_PROJECT_DIR を優先する）
base_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
repo_root=$(git -C "$base_dir" rev-parse --show-toplevel 2>/dev/null) || {
    debug "not a git repository: $base_dir"
    exit 0
}
[ -n "$repo_root" ] || exit 0

# 2) sync-state 存在確認（ハーネス未導入なら無干渉）
state_file="$repo_root/.claude/references/.sync-state.json"
[ -f "$state_file" ] || {
    debug "harness not installed (no .sync-state.json)"
    exit 0
}

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

# 4) 形式検証（jq 経路 / sed 経路のどちらで読んでも同一基準で検証する）
case "$last_synced" in
    ''|*[!0-9a-fA-F]*)
        debug "invalid last_synced_commit format"
        exit 0
        ;;
esac
if [ "${#last_synced}" -lt 7 ] || [ "${#last_synced}" -gt 40 ]; then
    debug "last_synced_commit length out of range"
    exit 0
fi

# 閾値は 1 以上 9 桁以内の整数のみ採用する（桁溢れで比較が失敗し通知が恒久的に無効化されるのを防ぐ）
# 通知を止めたい場合は十分大きい値（例: 100000）を設定する。sync-spec.md 節 1 を参照。
case "$threshold" in
    ''|*[!0-9]*) threshold=10 ;;
    *)
        if [ "${#threshold}" -gt 9 ] || [ "$threshold" -lt 1 ]; then
            threshold=10
        fi
        ;;
esac

# 5) HEAD からの到達可能性（rebase / force-push / シャロークローンで到達不能な場合は
#    harness-update 実行時に基準を選び直すため、ここでは無出力で終了する）
#    `cat-file -e` はオブジェクトの存在しか見ず、rebase で切り離された旧コミットも
#    gc されるまで残るため通過してしまう。祖先関係を直接判定する。
git -C "$repo_root" merge-base --is-ancestor "$last_synced" HEAD 2>/dev/null || {
    debug "last_synced_commit is not an ancestor of HEAD"
    exit 0
}

# 6) 乖離コミット数の取得（判定に必要なのは閾値到達の有無のみのため、
#    走査コストを --max-count で閾値件数に固定する）
drift=$(git -C "$repo_root" rev-list --count --max-count="$threshold" "${last_synced}..HEAD" 2>/dev/null) || {
    debug "rev-list failed"
    exit 0
}
case "$drift" in
    ''|*[!0-9]*) exit 0 ;;
esac

# 7) 閾値判定（到達時のみ additionalContext を出力）
#    出力は SessionStart フックの構造化 JSON 形式。jq へ依存しないよう printf で組み立てる。
#    message はハードコードされた固定文へ検証済みの数値（threshold）を埋め込んだものであり、
#    `"` と `\` を含まないため JSON エスケープは不要。文言を編集する際もこの 2 文字を入れないこと。
if [ "$drift" -ge "$threshold" ]; then
    debug "threshold reached: drift>=$threshold"
    message="[project-harness] .claude ハーネスの最終同期から ${threshold} コミット以上進行しています。仕様・設計ドキュメントが実装と乖離している可能性があるため、/project-harness:update の実行を推奨します。通知頻度は .claude/references/.sync-state.json の threshold_commits で調整できます。"
    printf '{"continue":true,"suppressOutput":false,"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$message"
else
    debug "below threshold: drift=$drift threshold=$threshold"
fi

exit 0
