#!/usr/bin/env bash
# project-harness: ハーネス健全性の決定論的検証
#
# authoring-spec.md 節 6 の機械判定可能な項目を検査する。
# harness-init / harness-update の検証フェーズから実行し、結果を報告に含める。
#
# 使い方:
#   bash validate_harness.sh [対象リポジトリのルート]
#   （省略時は CLAUDE_PROJECT_DIR、未設定なら cwd を使う）
#
# 終了コード:
#   0 = 全項目合格
#   1 = 違反あり（検出内容を stdout に出力）
#   2 = 検査不能（対象にハーネスが無い等）
#
# 本スクリプトは検証結果を返すことが目的のため、フックと異なりフェイルオープンしない。

set -u

target="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}"
harness_root="$target/.claude"
refs_root="$harness_root/references"

violations=0
report() { printf '%s\n' "$1"; }
fail() { report "  NG  $1"; violations=$((violations + 1)); }
pass() { report "  OK  $1"; }

if [ ! -d "$refs_root" ]; then
    report "ハーネスが見つかりません: $refs_root"
    exit 2
fi

report "ハーネス検証: $harness_root"
report ""

# --- 1. .claude/CLAUDE.md の存在と行数（100 行以内） ---
report "[1] .claude/CLAUDE.md"
if [ ! -f "$harness_root/CLAUDE.md" ]; then
    fail ".claude/CLAUDE.md が存在しない"
else
    lines=$(awk 'END{print NR}' "$harness_root/CLAUDE.md")
    if [ "$lines" -gt 100 ]; then
        fail ".claude/CLAUDE.md が 100 行を超過（${lines} 行）。詳細を references/ へ委譲すること"
    else
        pass ".claude/CLAUDE.md は ${lines} 行（100 行以内）"
    fi
fi

# --- 2. ルート CLAUDE.md からの到達性（@import） ---
report "[2] ルート CLAUDE.md からの到達性"
if [ ! -f "$target/CLAUDE.md" ]; then
    fail "ルート CLAUDE.md が存在しない（structure-spec.md 節 4.1 の最小スタブが必要）"
elif grep -q '@\.claude/CLAUDE\.md' "$target/CLAUDE.md" 2>/dev/null; then
    pass "ルート CLAUDE.md に @.claude/CLAUDE.md の import がある"
else
    fail "ルート CLAUDE.md に @.claude/CLAUDE.md の import がない（散文ポインタでは読み込みが保証されない）"
fi

# --- 3. .sync-state.json が valid JSON ---
report "[3] .sync-state.json"
state_file="$refs_root/.sync-state.json"
if [ ! -f "$state_file" ]; then
    fail ".sync-state.json が存在しない"
elif command -v jq >/dev/null 2>&1; then
    if jq -e . "$state_file" >/dev/null 2>&1; then
        pass ".sync-state.json は valid JSON"
    else
        fail ".sync-state.json が JSON として不正"
    fi
elif grep -q '"last_synced_commit"[[:space:]]*:' "$state_file" 2>/dev/null; then
    pass ".sync-state.json に last_synced_commit がある（jq 不在のため簡易確認）"
else
    fail ".sync-state.json に last_synced_commit が見つからない"
fi

# --- 4. frontmatter の必須フィールド（title / sources / updated） ---
report "[4] frontmatter 必須フィールド"
missing_fm=0
while IFS= read -r doc; do
    base=$(basename "$doc")
    [ "$base" = "CLAUDE.md" ] && continue
    # frontmatter ブロック（1 つ目と 2 つ目の `---` の間）を抽出する。
    # sources / related が複数エントリでも取りこぼさないよう固定行数では切らない。
    fm=$(awk 'NR==1 && $0!="---"{exit} /^---$/{c++; if(c==2) exit; next} c==1' "$doc" 2>/dev/null) || continue
    for field in title sources updated; do
        if ! printf '%s\n' "$fm" | grep -q "^${field}:"; then
            fail "frontmatter の ${field} が無い: ${doc#$target/}"
            missing_fm=$((missing_fm + 1))
        fi
    done
done < <(find "$refs_root" -name '*.md' -type f)
[ "$missing_fm" -eq 0 ] && pass "全ドキュメントに title / sources / updated がある"

# --- 5. 索引 CLAUDE.md とファイル実体の一致 ---
report "[5] 索引 CLAUDE.md とファイル実体の一致"
index_ng=0
while IFS= read -r dir; do
    idx="$dir/CLAUDE.md"
    [ -f "$idx" ] || { fail "索引が無い: ${dir#$target/}/CLAUDE.md"; index_ng=$((index_ng + 1)); continue; }
    for f in "$dir"/*.md; do
        [ -e "$f" ] || continue
        name=$(basename "$f")
        [ "$name" = "CLAUDE.md" ] && continue
        if ! grep -qF "$name" "$idx"; then
            fail "索引に未記載: ${dir#$target/}/${name}"
            index_ng=$((index_ng + 1))
        fi
    done
done < <(find "$refs_root" -mindepth 1 -type d ! -name archive)
[ "$index_ng" -eq 0 ] && pass "各フォルダの索引がファイル実体と一致している"

# --- 6. 未置換プレースホルダ ---
# テンプレート由来のプレースホルダは日本語を含むため文字種を限定しない。
# mermaid の判断ノード記法（`A{条件}`）との誤検知を避けるため、
# フェンス付きコードブロックの内側は検査対象から除外する。
report "[6] 未置換プレースホルダ"
ph_files=""
while IFS= read -r doc; do
    hit=$(awk '
        /^[[:space:]]*```/ { fence = !fence; next }
        !fence && /\{[^{}]+\}/ { print NR; exit }
    ' "$doc" 2>/dev/null)
    [ -n "$hit" ] && ph_files="${ph_files}${doc}:${hit}"$'\n'
done < <(find "$refs_root" -name '*.md' -type f; [ -f "$harness_root/CLAUDE.md" ] && echo "$harness_root/CLAUDE.md")

if [ -n "$ph_files" ]; then
    while IFS= read -r entry; do
        [ -n "$entry" ] || continue
        fpath="${entry%:*}"
        fline="${entry##*:}"
        fail "未置換プレースホルダ: ${fpath#$target/}（${fline} 行目）"
    done <<< "$ph_files"
else
    pass "未置換プレースホルダなし"
fi

# --- 7. 秘匿値パターンの混入 ---
report "[7] 秘匿値パターン"
secret_pat='(sk-[A-Za-z0-9]{16,}|ghp_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|glpat-[A-Za-z0-9_-]{16,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|[Pp]assword[[:space:]]*=[[:space:]]*[^<[:space:]]|[Pp][Ww][Dd][[:space:]]*=[[:space:]]*[^<[:space:]])'
sec=$(grep -rlE "$secret_pat" "$refs_root" "$harness_root/CLAUDE.md" 2>/dev/null || true)
if [ -n "$sec" ]; then
    printf '%s\n' "$sec" | while IFS= read -r f; do
        [ -n "$f" ] && report "  NG  秘匿値らしい記述: ${f#$target/}（該当記述を除去すること）"
    done
    violations=$((violations + 1))
else
    pass "秘匿値パターンの混入なし"
fi

report ""
if [ "$violations" -eq 0 ]; then
    report "検証結果: 全項目合格"
    exit 0
fi
report "検証結果: ${violations} 件の違反を検出"
exit 1
