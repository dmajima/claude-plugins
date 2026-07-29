#!/usr/bin/env bash
# resolve_base.sh - Resolve skill-router directories (Bash 版)
#
#
# Data base (index / config / sessions / logs)
#   1. ${CLAUDE_PLUGIN_DATA}
#   2. <repo-root>/.claude/.local/plugins/skill-router/  (walk parents from
#      ${CLAUDE_PROJECT_DIR:-$PWD} looking for .git)
#   3. <user-home>/.claude/.local/plugins/skill-router/
#   build_index.resolve_base_dir と lock-step で維持すること。
#
# Venv base (interpreter and its sentinels)
#   1. ${CLAUDE_PLUGIN_DATA}
#   2. <user-home>/.claude/.local/plugins/skill-router/
#   リポジトリ相対の階層は使わない。clone したリポジトリが
#   .venv/ を同梱していても、それを実行しないための境界。
#   venv_lifecycle.resolve_venv_base と lock-step で維持すること。
#
# 使い方:
#   source resolve_base.sh  → 関数を import
#   bash resolve_base.sh    → resolved data base を stdout に出力

skill_router_home_dir() {
  # Windows では USERPROFILE、それ以外はチルダ展開でホームを得る。
  # 環境変数名をパスに埋め込まないことで、path-portability の
  # 「シェル HOME 変数によるパス構築」を避ける。
  if [[ -n "${USERPROFILE:-}" ]]; then printf '%s' "$USERPROFILE"
  else printf '%s' ~
  fi
}

# Git Bash exposes $PWD as /c/Users/... while $USERPROFILE stays C:\Users\...,
# so the HOME boundary check below never matches without normalisation.
skill_router_normalise_path() {
  local raw="$1"
  [[ -z "$raw" ]] && return 0
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u -- "$raw" 2>/dev/null || printf '%s' "$raw"
  else
    printf '%s' "$raw"
  fi
}

skill_router_project_root() {
  local dir="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}"
  local home_dir trimmed parent
  home_dir="$(skill_router_normalise_path "$(skill_router_home_dir)")"
  home_dir="${home_dir%/}"
  home_dir="${home_dir%\\}"
  dir="$(skill_router_normalise_path "$dir")"

  while [[ -n "$dir" ]]; do
    trimmed="${dir%/}"
    trimmed="${trimmed%\\}"
    if [[ -z "$trimmed" || "$trimmed" == "." ]]; then return 1; fi

    if [[ -e "$dir/.git" ]]; then printf '%s' "$dir"; return 0; fi
    if [[ -n "$home_dir" && "$trimmed" == "$home_dir" ]]; then return 1; fi

    # dirname の fork を避ける（1 階層ごとに約 15ms かかるため）。
    parent="${dir%/*}"
    if [[ -z "$parent" || "$parent" == "$dir" ]]; then return 1; fi
    dir="$parent"
  done
  return 1
}

# build_index.resolve_base_dir は CLAUDE_PLUGIN_DATA を mkdir + 書込可能性で
# 検証してから採用する。同じ判定をここでも行わないと、書き込めない値が
# 設定された環境で Bash 側と Python 側が別のディレクトリを指す。
skill_router_plugin_data_dir() {
  local value="${CLAUDE_PLUGIN_DATA:-}"
  [[ -z "$value" ]] && return 1
  # Python 側（Path(...).expanduser()）と同じ正規化。前後空白を落とし、
  # 先頭の ~ を展開する。eval は使わない。
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  [[ "$value" == "~" || "$value" == "~/"* ]] && value="$(skill_router_home_dir)${value#\~}"
  [[ -z "$value" ]] && return 1
  mkdir -p "$value" 2>/dev/null || return 1
  [[ -w "$value" ]] || return 1
  printf '%s' "$value"
}

# build_index._has_symlink_component と lock-step。リポジトリ層に symlink 成分が
# あれば当該層を採用しない。clone したリポジトリが .claude/.local を外部への
# リンクとして同梱していると、ログやセッション履歴の書き込み先を奪われるため。
skill_router_path_has_symlink() {
  local current="$1" guard=0
  while [[ -n "$current" && $guard -lt 64 ]]; do
    [[ -L "$current" ]] && return 0
    local parent="${current%/*}"
    [[ -z "$parent" || "$parent" == "$current" ]] && break
    current="$parent"
    guard=$((guard + 1))
  done
  return 1
}

skill_router_base() {
  local data repo home_dir candidate
  if data="$(skill_router_plugin_data_dir)"; then printf '%s' "$data"; return; fi
  if repo="$(skill_router_project_root)"; then
    candidate="$repo/.claude/.local/plugins/skill-router"
    if ! skill_router_path_has_symlink "$candidate"; then
      printf '%s' "$candidate"; return
    fi
  fi
  home_dir="$(skill_router_home_dir)"
  if [[ -n "$home_dir" ]]; then
    printf '%s' "$home_dir/.claude/.local/plugins/skill-router"; return
  fi
}

skill_router_venv_base() {
  local data home_dir
  if data="$(skill_router_plugin_data_dir)"; then printf '%s' "$data"; return; fi
  home_dir="$(skill_router_home_dir)"
  if [[ -n "$home_dir" ]]; then
    printf '%s' "$home_dir/.claude/.local/plugins/skill-router"
  fi
}

# Print the venv interpreter when one is present and well-formed, else nothing.
# pyvenv.cfg の同伴を要求することで、python 実行ファイルだけを置いた残骸や
# 細工されたディレクトリを実行対象にしない。
skill_router_venv_python() {
  local vbase candidate resolved
  vbase="$(skill_router_venv_base)"
  [[ -z "$vbase" ]] && return 1
  [[ -f "$vbase/.venv/pyvenv.cfg" ]] || return 1
  # 完了マーカー（pip 成功後にのみ書かれる）を必須にする。venv 作成だけ済んで
  # 依存が入っていない中断状態を「使える venv」と誤認しないため。
  # ここで見るのは存在のみ。requirements のハッシュ照合は Python 側
  # （venv_lifecycle.venv_is_ready）が担当し、次回 SessionStart で作り直す。
  [[ -f "$vbase/.venv-ready" ]] || return 1
  for candidate in "$vbase/.venv/Scripts/python.exe" "$vbase/.venv/bin/python"; do
    [[ -x "$candidate" ]] || continue
    # POSIX の venv は bin/python をシステム python への symlink として作る。
    # リンクであること自体は正常なので拒否せず、辿れて実行可能なことだけ確認する。
    # 候補パスは <venv-base>（利用者所有領域）配下に固定されており、
    # リポジトリがここに介入する経路は無い。
    if [[ -L "$candidate" ]]; then
      resolved="$(readlink -f -- "$candidate" 2>/dev/null || true)"
      [[ -n "$resolved" && -x "$resolved" ]] || continue
    fi
    printf '%s' "$candidate"; return 0
  done
  return 1
}

# インタプリタパスが絶対パスかを判定する。相対パスは CWD（= リポジトリ）配下を
# 指しうるため実行してはならない。
# POSIX の /... と Windows の C:\... / C:/... の両方を受理する。
# 両フックがこの 1 実装を使う（同じ判定を各所に手書きすると、ブラケット式の
# 些細な差でプラットフォーム片方だけ無音で壊れる）。
skill_router_is_absolute_path() {
  case "$1" in
    /*) return 0 ;;
    [A-Za-z]:[\\/]*) return 0 ;;
    *) return 1 ;;
  esac
}

# disabled フラグを探索する 3 階層（プラグインデータ / リポジトリ / ホーム）を
# 1 行ずつ出力する。判定（skill_router_is_disabled）と解除（/router-toggle on）が
# 同じリストを消費するための単一の出典。
#
# 生の $CLAUDE_PLUGIN_DATA ではなく正規化済みの値を出す。`~/foo` のような値だと
# フラグを作る側（skill_router_base 経由）と見る側でパスが食い違い、OFF が無音で
# 失効し、`/router-toggle on` でも復帰できなくなる。
skill_router_disabled_candidates() {
  local data repo home_dir
  if data="$(skill_router_plugin_data_dir)"; then printf '%s\n' "$data"; fi
  repo="$(skill_router_project_root 2>/dev/null || true)"
  [[ -n "$repo" ]] && printf '%s\n' "$repo/.claude/.local/plugins/skill-router"
  home_dir="$(skill_router_home_dir)"
  [[ -n "$home_dir" ]] && printf '%s\n' "$home_dir/.claude/.local/plugins/skill-router"
  return 0
}

# ルーティング無効化フラグの判定。上記 3 階層のいずれかに disabled があれば真。
# 両フックと /router-toggle が同じ判断を使う。
skill_router_is_disabled() {
  local candidate
  while IFS= read -r candidate; do
    [[ -n "$candidate" && -f "$candidate/disabled" ]] && return 0
  done < <(skill_router_disabled_candidates)
  return 1
}

# Direct invocation: echo the resolved data base
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  base="$(skill_router_base)"
  [[ -n "$base" ]] && printf '%s\n' "$base"
fi
