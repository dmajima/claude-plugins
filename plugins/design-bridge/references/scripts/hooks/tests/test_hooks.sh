#!/usr/bin/env bash
# test_hooks.sh
#
# design-bridge のフック（mark_design_dirty.sh / block_unsynced_design.sh）の
# 回帰テスト。一時ディレクトリに擬似プロジェクトを作り、フックへ実際の
# フック入力 JSON を流して挙動を検証する。
#
# 実行: bash references/scripts/hooks/tests/test_hooks.sh
# 前提: jq が利用可能であること
#
# 終了コード: 0 = 全件 PASS、1 = FAIL あり

set -u

HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq が見つからないためテストを実行できません" >&2
  exit 0
fi

PROJ="$(mktemp -d)"
cleanup() { rm -rf "$PROJ"; }
trap cleanup EXIT

pass=0
fail=0
check() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    printf '  [PASS] %s\n' "$label"
    pass=$((pass + 1))
  else
    printf '  [FAIL] %s （期待: %s / 実際: %s）\n' "$label" "$expected" "$actual"
    fail=$((fail + 1))
  fi
}

setup_proj() {
  rm -rf "$PROJ"
  mkdir -p "$PROJ/.git" "$PROJ/.claude" "$PROJ/specs/screens" "$PROJ/mocks" "$PROJ/src"
  printf 'spec\n' > "$PROJ/specs/screens/S001_login.md"
  printf '<html></html>\n' > "$PROJ/mocks/S001_login.html"
  printf 'code\n' > "$PROJ/src/app.ts"
}

enable_bridge() {
  cat > "$PROJ/.claude/design-bridge.json" <<'JSON'
{
  "projectId": "00000000-0000-0000-0000-000000000000",
  "watch": [
    { "dir": "specs", "ext": "md" },
    { "dir": "mocks", "ext": "html" }
  ]
}
JSON
}

run_post() {
  printf '{"tool_input":{"file_path":"%s"},"cwd":"%s"}' "$1" "$PROJ" \
    | bash "$HOOKS/mark_design_dirty.sh" >/dev/null 2>&1
}

run_stop() {
  printf '{"cwd":"%s"}' "$PROJ" | bash "$HOOKS/block_unsynced_design.sh" >/dev/null 2>&1
  printf '%s' "$?"
}

pending_lines() {
  local p="$PROJ/.claude/.local/plugins/design-bridge/pending.txt"
  if [[ -f "$p" ]]; then grep -cve '^[[:space:]]*$' "$p"; else printf '0'; fi
}

echo "=== 1. design-bridge 未導入プロジェクト ==="
setup_proj
run_post "$PROJ/specs/screens/S001_login.md"
check "未導入なら記録しない" "0" "$(pending_lines)"
check "未導入なら Stop はブロックしない" "0" "$(run_stop)"

echo "=== 2. 導入済み: 監視対象の記録 ==="
setup_proj
enable_bridge
run_post "$PROJ/specs/screens/S001_login.md"
check "設計書 .md を記録" "1" "$(pending_lines)"
run_post "$PROJ/mocks/S001_login.html"
check "モック .html を記録" "2" "$(pending_lines)"
run_post "$PROJ/specs/screens/S001_login.md"
check "同一ファイル再編集は重複排除" "2" "$(pending_lines)"
run_post "$PROJ/src/app.ts"
check "監視対象外は記録しない" "2" "$(pending_lines)"

echo "=== 3. Windows 形式パスの正規化 ==="
setup_proj
enable_bridge
WINPATH="$(printf '%s' "$PROJ" | sed -E 's|^/([a-z])/|\U\1:\\\\|; s|/|\\\\|g')"
run_post "${WINPATH}\\\\specs\\\\screens\\\\S001_login.md"
check "C:\\ 形式のパスも記録できる" "1" "$(pending_lines)"

echo "=== 4. Stop フックのブロック ==="
setup_proj
enable_bridge
check "未反映なしなら通過" "0" "$(run_stop)"
run_post "$PROJ/specs/screens/S001_login.md"
check "未反映ありなら 1 回目はブロック" "2" "$(run_stop)"
check "2 回目もブロック" "2" "$(run_stop)"
check "3 回目もブロック" "2" "$(run_stop)"
check "上限超過（4 回目）は通過を許可" "0" "$(run_stop)"
check "上限解除後はカウンタがリセットされ再びブロック" "2" "$(run_stop)"

echo "=== 5. push 完了後（pending クリア） ==="
rm -f "$PROJ/.claude/.local/plugins/design-bridge/pending.txt"
check "pending クリア後は通過" "0" "$(run_stop)"
check "カウンタファイルも削除される" "0" \
  "$([[ -f "$PROJ/.claude/.local/plugins/design-bridge/block-count" ]] && echo 1 || echo 0)"

echo
printf '結果: PASS=%s FAIL=%s\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
