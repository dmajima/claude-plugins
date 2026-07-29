#!/usr/bin/env bash
# build_index_on_start.sh - SessionStart hook for skill-router (Bash 版)
#
#
# venv ライフサイクル管理 (references/scripts/routing/venv_lifecycle.py):
#   prepare（session-reset → cleanup-if-stale → ensure → interpreter 解決）
#   → build_index 実行 → 失敗時は env-error 判定 → rebuild → 再実行
#   prepare 内部の順序は venv_lifecycle.cmd_prepare が保証する。
#
# Fail-open: any error must not block the session start.

set +e

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

# Toggle check（route_prompt.sh と同一の 3 階層）。
# 無効化中に venv 構築やインデックス再構築を走らせない。
# shellcheck source=../commands/resolve_base.sh
source "$plugin_root/references/scripts/commands/resolve_base.sh"

if skill_router_is_disabled; then
  exit 0
fi


lifecycle="$plugin_root/references/scripts/routing/venv_lifecycle.py"
target="$plugin_root/references/scripts/routing/build_index.py"

stderr_temp=""
# 自分で作ったディレクトリだけを再帰削除する。mktemp が返すファイルの
# 親（/tmp 等）を消してはならないため、フォールバック時のみ値が入る変数に
# 分けて保持する。
fallback_dir=""
if command -v mktemp >/dev/null 2>&1; then
  stderr_temp="$(mktemp 2>/dev/null || true)"
fi
if [[ -z "$stderr_temp" ]]; then
  # mktemp が無い環境向けのフォールバック。予測可能な共有パスを使うと
  # 先回りされたシンボリックリンクへ書き込みうるため、プラグインのデータ領域に
  # 専用ディレクトリを 700 で作る。
  base_for_tmp="$(skill_router_venv_base 2>/dev/null || true)"
  [[ -z "$base_for_tmp" ]] && base_for_tmp="${TMPDIR:-/tmp}"
  fallback_dir="$base_for_tmp/tmp-session-$$"
  if mkdir -m 700 -p "$fallback_dir" 2>/dev/null; then
    stderr_temp="$fallback_dir/build.err"
  else
    fallback_dir=""
  fi
fi
trap '[[ -n "$fallback_dir" ]] && rm -rf -- "$fallback_dir" 2>/dev/null; [[ -n "$stderr_temp" ]] && rm -f -- "$stderr_temp" 2>/dev/null; true' EXIT

# session-reset → cleanup-if-stale → ensure → python-bin を 1 プロセスで実行する。
# 個別に呼ぶとインタプリタ起動が 4 回（約 0.45s × 4）発生し、順序の制約も
# このスクリプト側に露出してしまう。順序は prepare の内部で保証される。
venv_py="$("$python_bin" "$lifecycle" prepare --plugin-root "$plugin_root" 2>/dev/null)"
# 絶対パス以外は採用しない（resolve_base.sh の共有関数を使う）。相対パスは
# CWD（= リポジトリ）配下を指しうるため、clone 同梱のインタプリタを実行しない。
skill_router_is_absolute_path "$venv_py" || venv_py=""
[[ -z "${venv_py// /}" ]] && venv_py="$python_bin"

if [[ -n "$stderr_temp" ]]; then
  "$venv_py" "$target" >/dev/null 2>"$stderr_temp"
  build_rc=$?
else
  "$venv_py" "$target" >/dev/null 2>&1
  build_rc=$?
fi

if [[ $build_rc -ne 0 && -n "$stderr_temp" ]]; then
  "$python_bin" "$lifecycle" is-env-error --stderr-file "$stderr_temp" >/dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    "$python_bin" "$lifecycle" rebuild --plugin-root "$plugin_root" >/dev/null 2>&1
    venv_py="$("$python_bin" "$lifecycle" python-bin --plugin-root "$plugin_root" --no-construct 2>/dev/null)"
    # prepare 経路と同じ検証を通す。復旧経路だけ検証が抜けていると、
    # 例外時にのみ相対パスのインタプリタが実行される穴が残る。
    skill_router_is_absolute_path "$venv_py" || venv_py=""
    [[ -z "${venv_py// /}" ]] && venv_py="$python_bin"
    "$venv_py" "$target" >/dev/null 2>&1 || true
  fi
fi

exit 0
