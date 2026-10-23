#!/usr/bin/env bash
# block_unsynced_design.sh
#
# design-bridge プラグインの Stop フック。
#
# 画面設計書・モックに Claude Design へ未反映の変更が残っている場合、
# 終了コード 2 で応答の終了をブロックし、種別に応じた次の操作を促す。
# これにより「設計書を直したがデザインに反映し忘れた」状態を、運用ルール
# ではなくフック機構で防ぐ。
#
# design-bridge 未導入のプロジェクト（.claude/design-bridge.json 不在）では
# 何も行わない。
#
# 固着を防ぐ多層の歯止め:
#   1. ランタイムが渡す stop_hook_active が真なら即座に通過する
#   2. 連続ブロックが上限に達したら、その時点の未反映内容を「却下済み」として
#      記録し、内容が変わるまで二度とブロックしない（毎ターン再武装しない）
#   3. カウンタを更新できない状況（書き込み不可・ディレクトリ衝突）では
#      ブロックしない。上限が機能しない状態でブロックすると恒久ロックになる
#
# 設計: フェイルオープン（判定不能時は exit 0）。ブロックは確証がある時のみ。
#       jq には依存しない（cwd は $PWD へ、上限値は既定値へ縮退する）。

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/design_bridge_common.sh
source "${SCRIPT_DIR}/lib/design_bridge_common.sh" 2>/dev/null || exit 0

stdin="$(cat)"

# 歯止め 1: フック起因で既に継続中なら、ここで止めない。
if printf '%s' "$stdin" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

cwd=""
if [[ -n "${stdin//[[:space:]]/}" ]]; then
  if db_has_jq; then
    cwd="$(printf '%s' "$stdin" | jq -er '.cwd // empty' 2>/dev/null | tr -d '\r')"
  else
    cwd="$(printf '%s' "$stdin" \
      | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  fi
fi
[[ -z "$cwd" ]] && cwd="$PWD"

project_root="$(db_find_project_root "$cwd")"
[[ -z "$project_root" ]] && exit 0

db_is_enabled "$project_root" || exit 0

pending="$(db_pending_path "$project_root")"
count_file="$(db_block_count_path "$project_root")"
dismissed_file="$(db_dismissed_path "$project_root")"

cleanup_and_pass() {
  rm -f "$count_file" "$dismissed_file" 2>/dev/null
  exit 0
}

[[ -s "$pending" ]] || cleanup_and_pass

# 重複排除と検証は読み取り側で行う（書き込み側は追記のみ）。
specs=()
mocks=()
while IFS=$'\t' read -r kind rel; do
  [[ -z "$rel" ]] && continue
  db_is_safe_rel "$rel" || continue
  if [[ "$kind" == "mock" ]]; then
    mocks+=("$rel")
  else
    specs+=("$rel")
  fi
done < <(sort -u "$pending" 2>/dev/null)

total=$(( ${#specs[@]} + ${#mocks[@]} ))
[[ "$total" -eq 0 ]] && cleanup_and_pass

# 歯止め 2: 同じ内容で既に上限まで通知済みなら、内容が変わるまで黙る。
current_hash="$(db_content_hash "$pending")"
if [[ -f "$dismissed_file" ]]; then
  if [[ "$(cat "$dismissed_file" 2>/dev/null)" == "$current_hash" ]]; then
    exit 0
  fi
fi

blocked=0
if [[ -f "$count_file" ]]; then
  blocked="$(tr -cd '0-9' < "$count_file" 2>/dev/null | head -c 3)"
  [[ -z "$blocked" ]] && blocked=0
fi

limit="$(db_block_limit)"

if [[ "$blocked" -ge "$limit" ]]; then
  printf '%s' "$current_hash" > "$dismissed_file" 2>/dev/null
  rm -f "$count_file" 2>/dev/null
  printf '[design-bridge] 未反映の変更が %s 件残っていますが、連続 %s 回通知したため以降は通過させます。内容が変わるまで再通知しません。反映するときは design-push を実行してください。\n' \
    "$total" "$limit" >&2
  exit 0
fi

# 歯止め 3: カウンタを進められないならブロックしない。
# ここでブロックすると上限に到達できず、恒久的に応答を終了できなくなる。
if ! printf '%s' "$((blocked + 1))" > "$count_file" 2>/dev/null; then
  printf '[design-bridge] ブロック回数を記録できないため、未反映 %s 件を検出しましたが応答の終了を許可します（%s を確認してください）。\n' \
    "$total" "$count_file" >&2
  exit 0
fi

{
  printf '[design-bridge] Claude Design へ未反映の変更が %s 件あります。\n' "$total"
  if [[ "${#mocks[@]}" -gt 0 ]]; then
    printf '\nモック（design-push で反映する）:\n'
    printf '  - %s\n' "${mocks[@]:0:20}"
    [[ "${#mocks[@]}" -gt 20 ]] && printf '  ... 他 %s 件\n' "$(( ${#mocks[@]} - 20 ))"
  fi
  if [[ "${#specs[@]}" -gt 0 ]]; then
    printf '\n画面設計書（design-mock でモックを再生成する。モックの変更が不要なら design-push で画面イメージのみ更新する）:\n'
    printf '  - %s\n' "${specs[@]:0:20}"
    [[ "${#specs[@]}" -gt 20 ]] && printf '  ... 他 %s 件\n' "$(( ${#specs[@]} - 20 ))"
  fi
  printf '\n反映が不要な変更であれば、その旨をユーザーに確認したうえで clear_pending.sh で記録を解除してください。\n'
} >&2

exit 2
