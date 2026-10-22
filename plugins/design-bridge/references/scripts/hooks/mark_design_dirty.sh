#!/usr/bin/env bash
# mark_design_dirty.sh
#
# design-bridge プラグインの PostToolUse フック（matcher: Edit|Write|MultiEdit）。
#
# 画面設計書（specs/**/*.md）やモック（mocks/**/*.html）が変更されたとき、
# そのパスを「Claude Design へ未反映」として state に記録する。
# 記録された内容は Stop フック（block_unsynced_design.sh）が参照し、
# design-push が完了するまで応答の終了をブロックする。
#
# design-bridge 未導入のプロジェクト（.claude/design-bridge.json 不在）では
# 何も行わない。
#
# 設計: フェイルオープン（例外時も exit 0）。記録の失敗で作業を止めない。

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/design_bridge_common.sh
source "${SCRIPT_DIR}/lib/design_bridge_common.sh" 2>/dev/null || exit 0

command -v jq >/dev/null 2>&1 || exit 0

stdin="$(cat)"
[[ -z "${stdin//[[:space:]]/}" ]] && exit 0

file_path="$(printf '%s' "$stdin" | jq -er '.tool_input.file_path // empty' 2>/dev/null | tr -d '\r')"
[[ -z "$file_path" ]] && exit 0

cwd="$(printf '%s' "$stdin" | jq -er '.cwd // empty' 2>/dev/null | tr -d '\r')"
[[ -z "$cwd" ]] && cwd="$PWD"

file_path="$(db_normalize_path "$file_path")"

# プロジェクトルートは「変更されたファイルの位置」から探す。
# cwd がサブディレクトリへ移動していても正しいルートを得るため。
project_root="$(db_find_project_root "$(dirname "$file_path")")"
if [[ -z "$project_root" ]]; then
  project_root="$(db_find_project_root "$cwd")"
fi
[[ -z "$project_root" ]] && exit 0

db_is_enabled "$project_root" || exit 0

# プロジェクトルートからの相対パスへ変換（ルート外のファイルは対象外）
case "$file_path" in
  "${project_root}/"*) rel="${file_path#"${project_root}/"}" ;;
  *) exit 0 ;;
esac

config="$(db_config_path "$project_root")"
db_is_watched "$rel" "$config" || exit 0

state_dir="$(db_state_dir "$project_root")"
mkdir -p "$state_dir" 2>/dev/null || exit 0

pending="$(db_pending_path "$project_root")"
printf '%s\n' "$rel" >> "$pending" 2>/dev/null || exit 0

# 重複排除（一時ファイル経由。sort -o の同一ファイル指定は環境差があるため避ける）
tmp="${pending}.tmp.$$"
if sort -u "$pending" > "$tmp" 2>/dev/null; then
  mv -f "$tmp" "$pending" 2>/dev/null || rm -f "$tmp" 2>/dev/null
else
  rm -f "$tmp" 2>/dev/null
fi

exit 0
