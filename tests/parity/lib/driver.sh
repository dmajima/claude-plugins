#!/usr/bin/env bash
# tests/parity/lib/driver.sh
# parity test のテスト実行コア。
# .case ファイルを 1 つ受け取り、PowerShell 実装と Bash 実装を同じ条件で実行して
# stdout / stderr / exit code / ファイルシステム の 5 軸を比較する。
#
# 使い方:
#   source tests/parity/lib/driver.sh
#   parity_run_case <case_file>
#
# 出力（stdout）:
#   1 行サマリ: "PASS|FAIL|SKIP <id> [reason]"
#   差分発生時はその後ろに `<<<DIFF>>>` 〜 `<<</DIFF>>>` のブロック

# 依存ライブラリ
PARITY_LIB_DIR="${PARITY_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# shellcheck source=sandbox.sh
source "$PARITY_LIB_DIR/sandbox.sh"
# shellcheck source=path.sh
source "$PARITY_LIB_DIR/path.sh"
# shellcheck source=capture.sh
source "$PARITY_LIB_DIR/capture.sh"
# shellcheck source=normalize.sh
source "$PARITY_LIB_DIR/normalize.sh"
# shellcheck source=fs_snapshot.sh
source "$PARITY_LIB_DIR/fs_snapshot.sh"
# shellcheck source=json_canon.sh
source "$PARITY_LIB_DIR/json_canon.sh"

# pwsh 起動コマンドを検出する（フォールバック: powershell）
parity_pwsh_cmd() {
  if command -v pwsh >/dev/null 2>&1; then
    printf 'pwsh\n'
  elif command -v powershell >/dev/null 2>&1; then
    printf 'powershell\n'
  else
    echo "[driver] pwsh / powershell not found in PATH" >&2
    return 127
  fi
}

# 値の bool 判定（空・"0"・"false" 以外を真と見なす）
parity_is_true() {
  local v="${1:-}"
  case "$v" in
    ""|"0"|"false"|"False"|"FALSE"|"no"|"No"|"NO") return 1 ;;
    *) return 0 ;;
  esac
}

# parity_run_case <case_file>
parity_run_case() {
  local case_file="$1"
  if [[ ! -f "$case_file" ]]; then
    echo "FAIL ${case_file##*/} case_file_not_found"
    return 1
  fi

  # 既定値（case が上書き）
  local ID=""
  local SCRIPT_PS_REL=""
  local SCRIPT_BASH_REL=""
  local STDIN_FILE=""
  local PRE_FS=""
  local SKIP_BASH=""
  local SKIP_PS=""
  local COMPARE_STDOUT="true"
  local COMPARE_STDERR="true"
  local COMPARE_FS="true"
  local COMPARE_EXIT="true"
  local -a ARGS=()
  local -a ARGS_PS=()
  local -a ARGS_BASH=()
  local -a ENV_VARS=()
  local -a ENV_VARS_PS=()
  local -a ENV_VARS_BASH=()
  local -a POST_FS_INCLUDE=()
  local -a NORMALIZE=()
  local -a NORMALIZE_STDOUT=()
  local -a NORMALIZE_STDERR=()
  local -a NORMALIZE_FS=()
  local HOOK_JSON="false"

  # shellcheck source=/dev/null
  source "$case_file"

  if [[ -z "$ID" ]]; then
    ID="${case_file##*/}"
  fi

  # SKIP 判定（両方スキップなら全体スキップ扱い）
  if [[ -n "$SKIP_PS" && -n "$SKIP_BASH" ]]; then
    echo "SKIP $ID both_skipped"
    return 0
  fi
  if [[ -n "$SKIP_BASH" ]]; then
    echo "SKIP $ID bash_skipped:${SKIP_BASH}"
    return 0
  fi

  local repo_root
  repo_root="$(parity_repo_root)"
  local sandbox
  sandbox="$(parity_sandbox_create)"
  # PARITY_SANDBOX は normalize_abs_paths が参照する
  export PARITY_SANDBOX="$sandbox"
  trap 'parity_sandbox_destroy "$sandbox" || true; unset PARITY_SANDBOX' RETURN

  local ps_dir="$sandbox/_ps"
  local sh_dir="$sandbox/_sh"
  mkdir -p "$ps_dir/obs" "$sh_dir/obs"

  # 初期 FS テンプレートを各サイドにコピー
  if [[ -n "$PRE_FS" && -d "$repo_root/$PRE_FS" ]]; then
    cp -R "$repo_root/$PRE_FS/." "$ps_dir/"
    cp -R "$repo_root/$PRE_FS/." "$sh_dir/"
  fi

  # 引数の決定
  local -a ps_args=()
  local -a sh_args=()
  if [[ ${#ARGS_PS[@]} -gt 0 ]]; then
    ps_args=("${ARGS_PS[@]}")
  else
    ps_args=("${ARGS[@]+"${ARGS[@]}"}")
  fi
  if [[ ${#ARGS_BASH[@]} -gt 0 ]]; then
    sh_args=("${ARGS_BASH[@]}")
  else
    sh_args=("${ARGS[@]+"${ARGS[@]}"}")
  fi

  # 環境変数の決定（__SANDBOX__ 置換）
  local -a ps_env=()
  local -a sh_env=()
  local v
  for v in "${ENV_VARS[@]+"${ENV_VARS[@]}"}" "${ENV_VARS_PS[@]+"${ENV_VARS_PS[@]}"}"; do
    ps_env+=("$(parity_sandbox_substitute "$ps_dir" "$v")")
  done
  for v in "${ENV_VARS[@]+"${ENV_VARS[@]}"}" "${ENV_VARS_BASH[@]+"${ENV_VARS_BASH[@]}"}"; do
    sh_env+=("$(parity_sandbox_substitute "$sh_dir" "$v")")
  done

  # stdin ファイルパス
  local stdin_abs=""
  if [[ -n "$STDIN_FILE" ]]; then
    if [[ -f "$repo_root/$STDIN_FILE" ]]; then
      stdin_abs="$repo_root/$STDIN_FILE"
    elif [[ -f "$STDIN_FILE" ]]; then
      stdin_abs="$STDIN_FILE"
    fi
  fi

  # ---- PowerShell 側を実行 ----
  if [[ -n "$SKIP_PS" ]]; then
    echo "SKIP $ID ps_skipped:${SKIP_PS}"
    return 0
  fi
  local pwsh_cmd
  pwsh_cmd="$(parity_pwsh_cmd)" || { echo "FAIL $ID pwsh_not_found"; return 1; }

  # PowerShell ラッパー経由で起動し、Console エンコーディングを UTF-8 に強制する。
  # これにより Bash 側 (UTF-8) との出力比較で文字化けを防ぐ。
  local ps_env_arr=ps_env
  parity_capture "$ps_dir/obs" "$stdin_abs" "$ps_env_arr" "$ps_dir" \
    "$pwsh_cmd" -NoProfile -File "$PARITY_LIB_DIR/pwsh_runner.ps1" \
    "$repo_root/$SCRIPT_PS_REL" "${ps_args[@]+"${ps_args[@]}"}"

  # ---- Bash 側を実行 ----
  if [[ -z "$SCRIPT_BASH_REL" ]]; then
    echo "FAIL $ID bash_script_unset"
    return 1
  fi
  if [[ ! -f "$repo_root/$SCRIPT_BASH_REL" ]]; then
    echo "FAIL $ID bash_script_missing:$SCRIPT_BASH_REL"
    return 1
  fi
  local sh_env_arr=sh_env
  parity_capture "$sh_dir/obs" "$stdin_abs" "$sh_env_arr" "$sh_dir" \
    bash "$repo_root/$SCRIPT_BASH_REL" "${sh_args[@]+"${sh_args[@]}"}"

  # ---- 5 軸比較 ----
  local -a diffs=()

  _parity_compare_axis() {
    local axis="$1"   # stdout|stderr|exit
    local -a rules=()
    case "$axis" in
      stdout) rules=("${NORMALIZE[@]+"${NORMALIZE[@]}"}" "${NORMALIZE_STDOUT[@]+"${NORMALIZE_STDOUT[@]}"}") ;;
      stderr) rules=("${NORMALIZE[@]+"${NORMALIZE[@]}"}" "${NORMALIZE_STDERR[@]+"${NORMALIZE_STDERR[@]}"}") ;;
      exit)   rules=() ;;
    esac
    # HOOK_JSON=true なら stdout に json canonical を末尾追加
    if [[ "$axis" == "stdout" ]] && parity_is_true "$HOOK_JSON"; then
      rules+=("json")
    fi

    local ps_in="$ps_dir/obs/$axis"
    local sh_in="$sh_dir/obs/$axis"
    local ps_n="$ps_dir/obs/${axis}.norm"
    local sh_n="$sh_dir/obs/${axis}.norm"

    PARITY_SANDBOX="$ps_dir" parity_normalize "${rules[@]+"${rules[@]}"}" <"$ps_in" >"$ps_n"
    PARITY_SANDBOX="$sh_dir" parity_normalize "${rules[@]+"${rules[@]}"}" <"$sh_in" >"$sh_n"

    if ! diff -u "$ps_n" "$sh_n" >"$sandbox/diff_$axis"; then
      diffs+=("$axis")
    fi
  }

  if parity_is_true "$COMPARE_STDOUT"; then _parity_compare_axis stdout; fi
  if parity_is_true "$COMPARE_STDERR"; then _parity_compare_axis stderr; fi
  if parity_is_true "$COMPARE_EXIT"; then
    local ps_code sh_code
    ps_code="$(cat "$ps_dir/obs/exit" 2>/dev/null || echo "?")"
    sh_code="$(cat "$sh_dir/obs/exit" 2>/dev/null || echo "?")"
    if [[ "$ps_code" != "$sh_code" ]]; then
      printf -- '-pwsh %s\n+bash %s\n' "$ps_code" "$sh_code" >"$sandbox/diff_exit"
      diffs+=("exit")
    fi
  fi
  if parity_is_true "$COMPARE_FS"; then
    local -a inc=()
    if [[ ${#POST_FS_INCLUDE[@]} -gt 0 ]]; then
      local p
      for p in "${POST_FS_INCLUDE[@]}"; do
        # __SANDBOX__/foo を相対 foo に直す
        inc+=("${p#__SANDBOX__/}")
      done
    fi
    parity_fs_snapshot "$ps_dir" "${inc[@]+"${inc[@]}"}" >"$ps_dir/obs/fs.sha"
    parity_fs_snapshot "$sh_dir" "${inc[@]+"${inc[@]}"}" >"$sh_dir/obs/fs.sha"
    if ! diff -u "$ps_dir/obs/fs.sha" "$sh_dir/obs/fs.sha" >"$sandbox/diff_fs"; then
      diffs+=("fs")
    fi
  fi

  if [[ ${#diffs[@]} -eq 0 ]]; then
    echo "PASS $ID"
    return 0
  fi

  echo "FAIL $ID axes=${diffs[*]}"
  local axis
  for axis in "${diffs[@]}"; do
    echo "<<<DIFF $axis>>>"
    cat "$sandbox/diff_$axis" 2>/dev/null || true
    echo "<<</DIFF $axis>>>"
  done
  return 1
}
