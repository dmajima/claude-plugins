#!/usr/bin/env bash
# check_version_bump.sh - Stop フック（ADR-026 v2 真因対策）
#
# 目的:
#   Claude のターン終了時、ワーキングツリーに plugins/{name}/ 配下の
#   未コミット変更があり、かつ対応する plugin.json の version が
#   未更新の場合に警告を出す。
#
#   PreToolUse Edit ハードブロックの代替として、本来の問題
#   （バージョン更新漏れ）に直接的に対処する。
#
# 入力:
#   stdin: Claude Code から渡される Stop イベント JSON（本フックは内容不問）
#
# 出力:
#   - 該当変更なし or 全プラグインで version 更新済み: exit 0、無音
#   - version 未更新のプラグインあり: exit 0 + stderr に警告（fail-open）
#
# 設計:
#   - exit 0（fail-open）。Claude のターンを止めない
#   - stderr メッセージは Claude Code が次ターンの context として扱う想定
#   - git が利用できない / リポジトリでない環境では何もしない（無音 exit 0）

set -uo pipefail

# 入力 JSON は読み捨てる（ファイルディスクリプタ詰まり防止）
cat >/dev/null 2>&1 || true

# git 利用不可ならスキップ
if ! command -v git >/dev/null 2>&1; then
  exit 0
fi

# リポジトリ外ならスキップ
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

# main ブランチを特定（origin/main 優先、無ければ main、無ければ判定スキップ）
BASE=""
if git rev-parse --verify origin/main >/dev/null 2>&1; then
  BASE="origin/main"
elif git rev-parse --verify main >/dev/null 2>&1; then
  BASE="main"
fi

# 未コミット変更（staged + unstaged + untracked）一覧
UNCOMMITTED=$(git status --porcelain 2>/dev/null | sed -E 's/^...//' | sed -E 's/.* -> //')

# main から HEAD までのコミット済み差分
COMMITTED=""
if [ -n "$BASE" ]; then
  COMMITTED=$(git diff --name-only "$BASE..HEAD" 2>/dev/null || true)
fi

# 全変更ファイル（コミット済 + 未コミット）
ALL_CHANGED=$(printf '%s\n%s\n' "$COMMITTED" "$UNCOMMITTED" | grep -v '^$' | sort -u)
if [ -z "$ALL_CHANGED" ]; then
  exit 0
fi

# 変更された各プラグイン名を抽出
PLUGINS=$(printf '%s\n' "$ALL_CHANGED" | grep '^plugins/' | sed -E 's|^plugins/([^/]+)/.*|\1|' | sort -u)
if [ -z "$PLUGINS" ]; then
  exit 0
fi

WARNINGS=""
for plugin in $PLUGINS; do
  PJSON="plugins/$plugin/.claude-plugin/plugin.json"
  if [ ! -f "$PJSON" ]; then
    continue
  fi

  # main ブランチが特定できない環境では判定不能 → スキップ（fail-open）
  if [ -z "$BASE" ]; then
    continue
  fi

  # main の version vs 現在の version
  OLD_VERSION=$(git show "$BASE:$PJSON" 2>/dev/null | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1 || true)
  NEW_VERSION=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PJSON" | head -1 || true)

  # main 側に plugin.json 不在（新規プラグイン追加中）→ 通過
  if [ -z "$OLD_VERSION" ]; then
    continue
  fi

  if [ "$OLD_VERSION" = "$NEW_VERSION" ]; then
    WARNINGS="$WARNINGS  - $plugin: ブランチ全体で plugin.json の version が main から変わっていません（現在 $OLD_VERSION のまま）\n"
  fi
done

if [ -z "$WARNINGS" ]; then
  exit 0
fi

cat >&2 <<EOF
[extension-toolkit hook] バージョン更新漏れの可能性を検出:
$(printf '%b' "$WARNINGS")
versioning.md の方針: すべてのコミットで plugin.json の version を更新する。
コミット前に該当プラグインの plugin.json を更新してください。
（更新基準: メジャー = 新スキル/新コマンド/新 SSOT、マイナー = 既存拡張、パッチ = バグ修正等）
EOF

# fail-open（警告のみ）
exit 0
