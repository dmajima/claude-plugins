#!/usr/bin/env bash
# clear_pending.sh
#
# 未反映リスト（pending.tsv）からエントリを決定的に取り除く。
#
# 記録側（mark_design_dirty.sh）がスクリプトで決定的に動くのに対し、解除側が
# スキルの散文指示だけだと、部分 push のときに対象外のエントリまで消える・
# 消し漏れるといった事故が起きる。解除もスクリプトに寄せて、bridge-push 等の
# スキルからはこれを呼ぶだけにする。
#
# 使い方:
#   bash clear_pending.sh --project-root <path> --path specs/a.md --path mocks/a.html
#   bash clear_pending.sh --project-root <path> --all --drop-bundle
#
# --path には pending.tsv の第 2 列の値をそのまま渡すこと。正規化は行わない
# （`./mocks/a.html` のような表記は一致せず 0 件解除になる）。
#
# 終了コード:
#   0 = 正常（解除件数と残存件数を標準出力に出す）
#   2 = 引数エラー / 未導入 / 書き込み失敗 / state の経路に symlink

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/design_bridge_common.sh
source "${SCRIPT_DIR}/lib/design_bridge_common.sh" 2>/dev/null || {
  printf 'エラー: 共通ライブラリを読み込めません\n' >&2
  exit 2
}

usage() {
  cat >&2 <<'USAGE'
使い方: clear_pending.sh [options]

  --project-root <path>  対象プロジェクトのルート（省略時は現在地から探索）
  --path <rel>           取り除く相対パス（複数指定可。pending.tsv の値をそのまま）
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
      if [[ -z "${2:-}" ]]; then
        printf 'エラー: --project-root に値が必要です\n' >&2
        exit 2
      fi
      project_root="$2"; shift 2 ;;
    --path)
      if [[ -z "${2:-}" ]]; then
        printf 'エラー: --path に値が必要です\n' >&2
        exit 2
      fi
      paths+=("$2"); shift 2 ;;
    --all) clear_all=true; shift ;;
    --drop-bundle) drop_bundle=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'エラー: 不明なオプション: %s\n' "$1" >&2; usage; exit 2 ;;
  esac
done

if [[ "$clear_all" == false && "${#paths[@]}" -eq 0 ]]; then
  printf 'エラー: --path または --all のいずれかを指定してください\n' >&2
  usage
  exit 2
fi
if [[ "$clear_all" == true && "${#paths[@]}" -gt 0 ]]; then
  printf 'エラー: --path と --all は同時に指定できません\n' >&2
  exit 2
fi

# --path の値も記録側と同じ基準で検証する。改行を含む値を通すと
# 1 引数で複数行ぶんを巻き込んで削除してしまう。
for p in "${paths[@]:-}"; do
  [[ -z "$p" ]] && continue
  if ! db_is_trackable_rel "$p"; then
    printf 'エラー: 解除対象として扱えないパスです（制御文字・上位参照・絶対パス・過長のいずれか）: %q\n' "$p" >&2
    exit 2
  fi
done

if [[ -z "$project_root" ]]; then
  project_root="$(db_find_project_root "$PWD")"
fi
if [[ -z "$project_root" ]]; then
  printf 'エラー: プロジェクトルート（.git のあるディレクトリ）を特定できません\n' >&2
  exit 2
fi
project_root="$(db_normalize_path "$project_root")"

db_is_enabled "$project_root" || {
  printf 'エラー: design-bridge が導入されていません: %s\n' "$(db_config_path "$project_root")" >&2
  exit 2
}

pending="$(db_pending_path "$project_root")"
count_file="$(db_block_count_path "$project_root")"
dismissed_file="$(db_dismissed_path "$project_root")"
state_dir="$(db_state_dir "$project_root")"
bundle_dir="${state_dir}/bundle"

# state の経路に symlink があれば触らない（別のファイルを壊す恐れがある）。
for target in "$pending" "$count_file" "$dismissed_file" "$bundle_dir"; do
  if ! db_path_has_no_symlink "$project_root" "$target"; then
    printf 'エラー: state の経路に symlink が含まれます。解除を中止しました: %s\n' "$target" >&2
    exit 2
  fi
done

# 件数は Stop フックと同じ基準（追跡可能な行）で数える。
count_entries() {
  [[ -s "$pending" ]] || { printf '0'; return 0; }
  local n=0 kind rel
  while IFS=$'\t' read -r kind rel; do
    [[ -z "$rel" ]] && continue
    db_is_trackable_rel "$rel" || continue
    n=$((n + 1))
  done < <(sort -u "$pending" 2>/dev/null)
  printf '%s' "$n"
}

before="$(count_entries)"

if [[ "$clear_all" == true ]]; then
  rm -f -- "$pending" 2>/dev/null
  after=0
else
  if [[ -s "$pending" ]]; then
    list_file="$(mktemp "${state_dir}/.drop.XXXXXX" 2>/dev/null)" || {
      printf 'エラー: 一時ファイルを作成できません\n' >&2
      exit 2
    }
    tmp_file="$(mktemp "${state_dir}/.tmp.XXXXXX" 2>/dev/null)" || {
      rm -f -- "$list_file" 2>/dev/null
      printf 'エラー: 一時ファイルを作成できません\n' >&2
      exit 2
    }
    printf '%s\n' "${paths[@]}" > "$list_file" 2>/dev/null || {
      rm -f -- "$list_file" "$tmp_file" 2>/dev/null
      printf 'エラー: 一時ファイルへ書き込めません\n' >&2
      exit 2
    }
    # 2 列目（相対パス）が指定リストに含まれる行を落とす。
    if awk -F'\t' 'NR==FNR { drop[$0]=1; next } !($2 in drop)' \
         "$list_file" "$pending" > "$tmp_file" 2>/dev/null; then
      if ! mv -f -- "$tmp_file" "$pending" 2>/dev/null; then
        rm -f -- "$tmp_file" "$list_file" 2>/dev/null
        printf 'エラー: 未反映リストを更新できません\n' >&2
        exit 2
      fi
    else
      rm -f -- "$tmp_file" "$list_file" 2>/dev/null
      printf 'エラー: 未反映リストの加工に失敗しました\n' >&2
      exit 2
    fi
    rm -f -- "$list_file" 2>/dev/null
  fi
  after="$(count_entries)"
  # 空になったファイルは残さない
  [[ "$after" -eq 0 ]] && rm -f -- "$pending" 2>/dev/null
fi

# 残りが無くなったら、ブロック関連の状態もまとめて解除する。
if [[ "$after" -eq 0 ]]; then
  rm -rf -- "$count_file" "$dismissed_file" 2>/dev/null
else
  # 内容が変わったので却下済みマーカーは無効化する。
  rm -rf -- "$dismissed_file" 2>/dev/null
fi

if [[ "$drop_bundle" == true ]]; then
  rm -rf -- "$bundle_dir" 2>/dev/null
fi

printf '解除: %s 件 / 残存: %s 件\n' "$(( before - after ))" "$after"
exit 0
