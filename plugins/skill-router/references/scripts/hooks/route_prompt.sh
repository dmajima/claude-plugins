#!/usr/bin/env bash
# route_prompt.sh - UserPromptSubmit hook for skill-router (Bash 版)
#
#
# CRITICAL: stdin JSON は Bash で parse せず、Python (json.load) に委譲する。
# Bash の責務は: Python interpreter の選択 / toggle (disabled) check / stdin の素通し のみ。
#
# Fail-open: any error must not block the user prompt.
# UserPromptSubmit の終了コード 2 は Claude Code にとって「プロンプトを破棄せよ」の
# 意味を持つ。route.py は常に 0 を返すが、インタプリタ起動失敗（rc=2 等）は
# その外側で起きるため、本スクリプトは常に exit 0 で終端する。

set +e

# stdin を最初に読み取って保持
stdin_payload="$(cat)"

plugin_root="${CLAUDE_PLUGIN_ROOT:-}"
if [[ -z "$plugin_root" ]]; then
  script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  plugin_root="$(cd "$script_dir/../../.." && pwd)"
fi

python_bin=""
if command -v python3 >/dev/null 2>&1; then
  python_bin="$(command -v python3)"
elif command -v python >/dev/null 2>&1; then
  python_bin="$(command -v python)"
fi
[[ -z "$python_bin" ]] && exit 0

# Toggle check
# shellcheck source=../commands/resolve_base.sh
source "$plugin_root/references/scripts/commands/resolve_base.sh"

if skill_router_is_disabled; then
  exit 0
fi


# インタプリタは Bash 側で選択する。venv_lifecycle を起動して尋ねると
# プロンプト経路に Python プロセスがもう 1 回増えるため、30s 予算では割に合わない。
# venv が無い（= 埋め込み未使用）場合はシステム Python で heuristic 経路が動く。
# 最終利用時刻マーカーは route.py 自身が更新する（venv 内で動いたときのみ）。
venv_py="$(skill_router_venv_python 2>/dev/null || true)"
# 絶対パス検証は resolve_base.sh の共有関数に一本化する。同じ判定を各所に
# 手書きすると、ブラケット式の些細な差でプラットフォーム片方だけが無音で壊れる。
skill_router_is_absolute_path "$venv_py" || venv_py=""
[[ -z "${venv_py// /}" ]] && venv_py="$python_bin"

route_script="$plugin_root/references/scripts/routing/route.py"

# Python に stdin を渡して起動。stderr は捕捉し、失敗時のみ error.log に残す。
# 素通しするとフック失敗のたびにユーザへノイズが出るため。
stderr_temp=""
if command -v mktemp >/dev/null 2>&1; then
  stderr_temp="$(mktemp 2>/dev/null || true)"
fi
# フックが timeout で打ち切られると下の rm には到達しないため、trap でも
# 後始末する。自分が作ったファイル 1 個だけを対象にし、親ディレクトリには
# 触れない（SessionStart 側と同じ原則）。
trap '[[ -n "$stderr_temp" ]] && rm -f -- "$stderr_temp" 2>/dev/null; true' EXIT

if [[ -n "$stderr_temp" ]]; then
  printf '%s' "$stdin_payload" | "$venv_py" "$route_script" 2>"$stderr_temp"
  route_rc=$?
  if [[ $route_rc -ne 0 && -s "$stderr_temp" ]]; then
    base="$(skill_router_base 2>/dev/null || true)"
    if [[ -n "$base" && -d "$base" ]]; then
      # Python 側（config_io.open_append）と同じくリンクは追従しない。
      # `<base>` はリポジトリ配下に解決されうるため、リンクを辿ると
      # 切り詰め（: >）と追記の対象をリポジトリに選ばれる。
      [[ -L "$base/error.log" ]] && rm -f -- "$base/error.log" 2>/dev/null
      # route.py 側と同じ 1MiB 上限。この経路が使われるのは Python の起動自体が
      # 失敗し続ける構成であり、上限が最も必要になる。
      if [[ -f "$base/error.log" ]]          && [[ "$(wc -c <"$base/error.log" 2>/dev/null || echo 0)" -gt 1048576 ]]; then
        : >"$base/error.log"
      fi
      {
        printf '[route_prompt] interpreter=%s rc=%s\n' "$venv_py" "$route_rc"
        cat -- "$stderr_temp"
      } >>"$base/error.log" 2>/dev/null
    fi
  fi
  rm -f -- "$stderr_temp" 2>/dev/null
else
  printf '%s' "$stdin_payload" | "$venv_py" "$route_script"
fi

# Stale-venv teardown は SessionStart (build_index_on_start.sh) が担当する。
exit 0
