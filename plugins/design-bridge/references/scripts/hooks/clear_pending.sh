#!/usr/bin/env bash
# clear_pending.sh
#
# 未反映リスト（pending.tsv）からエントリを決定的に取り除く。
#
# 記録側（mark_design_dirty.sh）がスクリプトで決定的に動くのに対し、解除側が
# スキルの散文指示だけだと、部分 push のときに対象外のエントリまで消える・
# 消し漏れるといった事故が起きる。解除もスクリプトに寄せて、design-push 等の
# スキルからはこれを呼ぶだけにする。
#
# 使い方:
#   bash clear_pending.sh --project-root <path> --path specs/a.md --path mocks/a.html
#   bash clear_pending.sh --project-root <path> --all --drop-bundle
#
# 終了コード:
#   0 = 正常（削除件数と残存件数を標準出力に出す）
#   2 = 引数エラー / 未導入 / 書き込み失敗

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/design_bridge_common.sh
source "${SCRIPT_DIR}/lib/design_bridge_common.sh" 2>/dev/null || {
  printf '共通ライブラリを読み込めません\n' >&2
  exit 2
}

usage() {
  cat >&2 <<'USAGE'
使い方: clear_pending.sh [options]

  --project-root <path>  対象プロジェクトのルート（省略時は現在地から探索）
  --path <rel>           取り除く相対パス（複数指定可）
  --all                  すべての未反映記録を取り除く
  --drop-bundle          push 用バンドルディレクトリも削除する
  -h, --help             このヘルプ

--path と --all はいずれか一方を指定する。
USAGE
}

project_root=""
paths=()
clear_all=false
drop_bundle=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root)
      [[ -z "${2:-}" ]] && { usage; exit 2; }
      project_root="$2"; shift 2 ;;
    --path)
      [[ -z "${2:-}" ]] && { usage; exit 2; }
      paths+=("$2"); shift 2 ;;
    --all) clear_all=true; shift ;;
    --drop-bundle) drop_bundle=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf '不明なオプション: %s\n' "$1" >&2; usage; exit 2 ;;
  esac
done

if [[ "$clear_all" == false && "${#paths[@]}" -eq 0 ]]; then
  printf '--path または --all のいずれかを指定してください\n' >&2
  usage
  exit 2
fi
if [[ "$clear_all" == true && "${#paths[@]}" -gt 0 ]]; then
  printf '--path と --all は同時に指定できません\n' >&2
  exit 2
fi

if [[ -z "$project_root" ]]; then
  project_root="$(db_find_project_root "$PWD")"
fi
[[ -z "$project_root" ]] && {
  printf 'プロジェクトルート（.git のあるディレクトリ）を特定できません\n' >&2
  exit 2
}
project_root="$(db_normalize_path "$project_root")"

db_is_enabled "$project_root" || {
  printf 'design-bridge が導入されていません: %s\n' "$(db_config_path "$project_root")" >&2
  exit 2
}

pending="$(db_pending_path "$project_root")"
count_file="$(db_block_count_path "$project_root")"
dismissed_file="$(db_dismissed_path "$project_root")"
bundle_dir="$(db_state_dir "$project_root")/bundle"

count_entries() {
  [[ -s "$pending" ]] || { printf '0'; return 0; }
  sort -u "$pending" 2>/dev/null | grep -cve '^[[:space:]]*$'
}

before="$(count_entries)"

if [[ "$clear_all" == true ]]; then
  rm -f "$pending" 2>/dev/null
  after=0
else
  if [[ -s "$pending" ]]; then
    list_file="${pending}.drop.$$"
    tmp_file="${pending}.tmp.$$"
    printf '%s\n' "${paths[@]}" > "$list_file" 2>/dev/null || {
      printf '一時ファイルを作成できません\n' >&2
      exit 2
    }
    # 2 列目（相対パス）が指定リストに含まれる行を落とす。
    if awk -F'\t' 'NR==FNR { drop[$0]=1; next } !($2 in drop)' \
         "$list_file" "$pending" > "$tmp_file" 2>/dev/null; then
      mv -f "$tmp_file" "$pending" 2>/dev/null || {
        rm -f "$tmp_file" "$list_file" 2>/dev/null
        printf '未反映リストを更新できません\n' >&2
        exit 2
      }
    else
      rm -f "$tmp_file" "$list_file" 2>/dev/null
      printf '未反映リストの加工に失敗しました\n' >&2
      exit 2
    fi
    rm -f "$list_file" 2>/dev/null
  fi
  after="$(count_entries)"
  # 空になったファイルは残さない
  [[ "$after" -eq 0 ]] && rm -f "$pending" 2>/dev/null
fi

# 残りが無くなったら、ブロック関連の状態もまとめて解除する。
if [[ "$after" -eq 0 ]]; then
  rm -f "$count_file" "$dismissed_file" 2>/dev/null
else
  # 内容が変わったので却下済みマーカーは無効化する。
  rm -f "$dismissed_file" 2>/dev/null
fi

if [[ "$drop_bundle" == true ]]; then
  rm -rf "$bundle_dir" 2>/dev/null
fi

printf '解除: %s 件 / 残存: %s 件\n' "$(( before - after ))" "$after"
exit 0
