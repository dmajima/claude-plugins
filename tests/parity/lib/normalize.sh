#!/usr/bin/env bash
# tests/parity/lib/normalize.sh
# stdout / stderr の正規化関数群と、配列を順次適用するパイプライン関数。
#
# 使い方:
#   NORMALIZE=("crlf" "timestamps" "abs_paths" "uuid" "pid")
#   PARITY_SANDBOX="/tmp/parity-xxx"   # abs_paths で <SANDBOX> へ置換する元値
#   parity_normalize "$NORMALIZE[@]" < input > output

# 個別正規化関数（filter として stdin -> stdout）

parity_norm_crlf() {
  tr -d '\r'
}

parity_norm_trailing_ws() {
  sed -E 's/[[:space:]]+$//'
}

parity_norm_timestamps() {
  # ISO 8601 / yyyyMMdd_NN_ / 30 days ago 形式の数値日時を <TS> に畳む
  sed -E \
    -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z?/<TS>/g' \
    -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}(:[0-9]{2})?/<TS>/g' \
    -e 's/[0-9]{8}_[0-9]{2}_/<SESSION>_/g'
}

parity_norm_abs_paths() {
  # PARITY_SANDBOX 環境変数を <SANDBOX> へ置換。
  # Windows 環境では以下の変種すべてに対応する:
  #   - Unix 形式 (/tmp/parity-xxx, /c/Users/...)
  #   - Windows 長い名前 (C:\Users\wwdmajima\AppData\...)
  #   - Windows 短い名前 8.3 (C:\Users\WWDMAJ~1\AppData\...)
  #   - 上記のフォワードスラッシュ版
  local sb="${PARITY_SANDBOX:-}"
  if [[ -z "$sb" ]]; then
    cat
    return
  fi

  local -a patterns=("$sb")
  if command -v cygpath >/dev/null 2>&1; then
    local sb_win sb_short
    sb_win="$(cygpath -w -- "$sb" 2>/dev/null || true)"
    sb_short="$(cygpath -w -s -- "$sb" 2>/dev/null || true)"
    if [[ -n "$sb_win" ]]; then
      patterns+=("$sb_win" "${sb_win//\\/\/}")
    fi
    if [[ -n "$sb_short" && "$sb_short" != "$sb_win" ]]; then
      patterns+=("$sb_short" "${sb_short//\\/\/}")
    fi
  fi

  # sed スクリプトを構築（長いパターンを先に置換して部分一致漏れを防ぐ）
  # 重複除去 + 文字列長降順ソート
  local -a uniq_sorted=()
  local p
  mapfile -t uniq_sorted < <(printf '%s\n' "${patterns[@]}" | LC_ALL=C awk '!seen[$0]++' | awk '{print length, $0}' | LC_ALL=C sort -rn | cut -d' ' -f2-)

  local sed_script=""
  for p in "${uniq_sorted[@]}"; do
    [[ -z "$p" ]] && continue
    # sed の区切り | を含まない前提（Windows / Unix パスとも | を含まない）
    local p_esc
    # sed のメタ文字 (\, |, &, ., *, [, ], (, ), {, }, +, ?, ^, $) のうち、
    # 単純置換に必要な \ と | のみエスケープ。他は sed -E のリテラルとして扱う。
    p_esc="${p//\\/\\\\}"
    p_esc="${p_esc//|/\\|}"
    sed_script+="s|${p_esc}|<SANDBOX>|g;"
  done
  # 最後にバックスラッシュをフォワードスラッシュに統一
  sed_script+='s|\\|/|g;'

  sed -E "$sed_script"
}

parity_norm_uuid() {
  sed -E 's/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/<UUID>/gi'
}

parity_norm_pid() {
  sed -E 's/\bpid[:=][0-9]+/pid=<PID>/gi'
}

parity_norm_json() {
  # jq -S でキーソートしつつ canonical 化。非 JSON 行はそのまま通す。
  if jq -S . >/dev/null 2>&1 <"${1:-/dev/null}"; then
    jq -S . <"${1:-/dev/null}"
  else
    cat "${1:-/dev/stdin}"
  fi
}

parity_norm_python_trace() {
  # Python トレースバックの絶対パスを <PY_TRACE> に畳む
  sed -E 's|File "[^"]+", line [0-9]+|File "<PY>", line <N>|g'
}

parity_norm_git_sha() {
  # 40 桁および 7-12 桁の hex を <SHA> に置換（行頭・空白後限定で誤爆を抑制）
  sed -E 's/\b[0-9a-f]{40}\b/<SHA>/g; s/\bcommit [0-9a-f]{7,12}\b/commit <SHA>/g'
}

# parity_normalize <rules...>
#   stdin に対し rules を順次適用して stdout に出す。
parity_normalize() {
  local -a rules=("$@")
  if [[ ${#rules[@]} -eq 0 ]]; then
    cat
    return
  fi

  # 各 rule を関数名にマップしてパイプラインを構築
  local cmd="cat"
  local rule
  for rule in "${rules[@]}"; do
    case "$rule" in
      crlf)          cmd+=" | parity_norm_crlf" ;;
      trailing_ws)   cmd+=" | parity_norm_trailing_ws" ;;
      timestamps)    cmd+=" | parity_norm_timestamps" ;;
      abs_paths)     cmd+=" | parity_norm_abs_paths" ;;
      uuid)          cmd+=" | parity_norm_uuid" ;;
      pid)           cmd+=" | parity_norm_pid" ;;
      python_trace)  cmd+=" | parity_norm_python_trace" ;;
      git_sha)       cmd+=" | parity_norm_git_sha" ;;
      json)          cmd+=" | parity_norm_json" ;;
      *)
        echo "[normalize] unknown rule: $rule" >&2
        return 2
        ;;
    esac
  done

  # 各関数は export されている前提（このファイルを source していれば呼べる）
  bash -c "$cmd"
}
export -f parity_norm_crlf parity_norm_trailing_ws parity_norm_timestamps \
          parity_norm_abs_paths parity_norm_uuid parity_norm_pid \
          parity_norm_python_trace parity_norm_git_sha parity_norm_json
