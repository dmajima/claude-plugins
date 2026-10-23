#!/usr/bin/env bash
# mark_design_dirty.sh
#
# design-bridge プラグインの PostToolUse フック（matcher: Edit|Write|MultiEdit）。
#
# 画面設計書（既定 specs 配下の .md）やモック（既定 mocks 配下の .html）が
# 変更されたとき、そのパスを種別付きで「Claude Design へ未反映」として
# state に記録する。記録内容は Stop フック（block_unsynced_design.sh）が参照し、
# 反映が済むまで応答の終了をブロックする。
#
# design-bridge 未導入のプロジェクト（.claude/design-bridge.json 不在）では
# 何も行わない。
#
# 設計:
#   - フェイルオープン（例外時も exit 0）。記録の失敗で作業を止めない。
#   - 追記のみで重複排除を行わない。read-modify-write にすると、同一ターンで
#     複数ファイルが並列編集されたときに lost update で記録が消える。
#     重複排除は読み取り側（Stop フック・design-status）が sort -u で行う。
#   - jq は任意依存。無ければ sed で抽出する（縮退するが機能は止めない）。

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/design_bridge_common.sh
source "${SCRIPT_DIR}/lib/design_bridge_common.sh" 2>/dev/null || exit 0

stdin="$(cat)"
[[ -z "${stdin//[[:space:]]/}" ]] && exit 0

# 入力 JSON から値を取り出す。jq があれば jq、無ければ sed で縮退抽出する。
if db_has_jq; then
  file_path="$(printf '%s' "$stdin" | jq -er '.tool_input.file_path // empty' 2>/dev/null | tr -d '\r')"
  cwd="$(printf '%s' "$stdin" | jq -er '.cwd // empty' 2>/dev/null | tr -d '\r')"
else
  file_path="$(printf '%s' "$stdin" \
    | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  cwd="$(printf '%s' "$stdin" \
    | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi

[[ -z "$file_path" ]] && exit 0
[[ -z "$cwd" ]] && cwd="$PWD"

file_path="$(db_normalize_path "$file_path")"

# プロジェクトルートは「変更されたファイルの位置」から探す。
# cwd がサブディレクトリへ移動していても正しいルートを得るため。
project_root="$(db_find_project_root "$(dirname -- "$file_path")")"
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

# 記録してよい形のパスか検証する。ここを通った値だけが後で stderr 経由で
# モデルのコンテキストへ渡るため、検証は記録の時点で行う。
db_is_safe_rel "$rel" || exit 0

config="$(db_config_path "$project_root")"
kind="$(db_classify "$rel" "$config")" || exit 0

state_dir="$(db_state_dir "$project_root")"
if ! mkdir -p "$state_dir" 2>/dev/null; then
  printf '[design-bridge] state ディレクトリを作成できないため、未反映の記録を省略しました: %s\n' \
    "$state_dir" >&2
  exit 0
fi

pending="$(db_pending_path "$project_root")"
if ! printf '%s\t%s\n' "$kind" "$rel" >> "$pending" 2>/dev/null; then
  printf '[design-bridge] 未反映リストへ書き込めませんでした。このファイルの変更は検出対象から外れます: %s\n' \
    "$rel" >&2
  exit 0
fi

# 未反映の内容が変わったので、却下済みマーカーを解除して再びブロック対象に戻す。
rm -f "$(db_dismissed_path "$project_root")" 2>/dev/null

exit 0
