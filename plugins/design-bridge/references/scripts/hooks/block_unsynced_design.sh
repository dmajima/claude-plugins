#!/usr/bin/env bash
# block_unsynced_design.sh
#
# design-bridge プラグインの Stop フック。
#
# 画面設計書・モックに Claude Design へ未反映の変更が残っている場合、
# 終了コード 2 で応答の終了をブロックし、design-push の実行を促す。
# これにより「設計書を直したがデザインに反映し忘れた」状態を、運用ルール
# ではなくフック機構で防ぐ。
#
# design-bridge 未導入のプロジェクト（.claude/design-bridge.json 不在）では
# 何も行わない。
#
# 無限ループ防止: 連続ブロック回数を記録し、上限（既定 3 回）に達したら
# 警告のみを出して終了を許可する。push が繰り返し失敗する状況で
# セッションが固まることを防ぐ。
#
# 設計: フェイルオープン（判定不能時は exit 0）。ブロックは確証がある時のみ。

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/design_bridge_common.sh
source "${SCRIPT_DIR}/lib/design_bridge_common.sh" 2>/dev/null || exit 0

command -v jq >/dev/null 2>&1 || exit 0

stdin="$(cat)"
cwd=""
if [[ -n "${stdin//[[:space:]]/}" ]]; then
  cwd="$(printf '%s' "$stdin" | jq -er '.cwd // empty' 2>/dev/null | tr -d '\r')"
fi
[[ -z "$cwd" ]] && cwd="$PWD"

project_root="$(db_find_project_root "$cwd")"
[[ -z "$project_root" ]] && exit 0

db_is_enabled "$project_root" || exit 0

pending="$(db_pending_path "$project_root")"
count_file="$(db_block_count_path "$project_root")"

# 未反映なし: カウンタをリセットして通過
if [[ ! -s "$pending" ]]; then
  rm -f "$count_file" 2>/dev/null
  exit 0
fi

pending_count="$(grep -cve '^[[:space:]]*$' "$pending" 2>/dev/null)"
[[ -z "$pending_count" ]] && pending_count=0
if [[ "$pending_count" -eq 0 ]]; then
  rm -f "$count_file" 2>/dev/null
  exit 0
fi

# 連続ブロック回数の確認
blocked=0
if [[ -f "$count_file" ]]; then
  blocked="$(tr -cd '0-9' < "$count_file" 2>/dev/null)"
  [[ -z "$blocked" ]] && blocked=0
fi

config="$(db_config_path "$project_root")"
limit="$(db_block_limit "$config")"

if [[ "$blocked" -ge "$limit" ]]; then
  rm -f "$count_file" 2>/dev/null
  printf '[design-bridge] Claude Design へ未反映の変更が %s 件残っていますが、連続ブロック上限（%s 回）に達したため応答の終了を許可します。後ほど design-push スキルで反映してください。\n' \
    "$pending_count" "$limit" >&2
  exit 0
fi

printf '%s' "$((blocked + 1))" > "$count_file" 2>/dev/null

{
  printf '[design-bridge] Claude Design へ未反映の変更が %s 件あります:\n' "$pending_count"
  grep -ve '^[[:space:]]*$' "$pending" 2>/dev/null | head -20 | sed 's/^/  - /'
  if [[ "$pending_count" -gt 20 ]]; then
    printf '  ... 他 %s 件\n' "$((pending_count - 20))"
  fi
  printf '\n'
  printf 'design-push スキル（/design-push）を実行し、スクリーンショット再生成と claude.ai/design への反映を完了してください。\n'
  printf '反映が不要な変更であれば、その旨をユーザーに確認したうえで %s を削除してください。\n' \
    "$(db_pending_path "$project_root")"
} >&2

exit 2
