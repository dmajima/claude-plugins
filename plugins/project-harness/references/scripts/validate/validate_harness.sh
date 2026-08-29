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
# report はメッセージ中の制御文字（改行・ESC 等）を除去し 1024 バイトで打ち切る。
# ファイル名・frontmatter 値は未信頼入力であり、無加工で転記するとレポートへの偽装行注入経路になるため。
report() { printf '%s' "$1" | LC_ALL=C tr -d '\000-\037\177' | cut -b -1024; printf '\n'; }
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
    # 標準入力渡しにする（ネイティブ jq.exe へ角括弧等を含む POSIX パスを渡すと開けない環境があるため）
    if jq -e . < "$state_file" >/dev/null 2>&1; then
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
while IFS= read -r -d '' doc; do
    base=$(basename "$doc")
    [ "$base" = "CLAUDE.md" ] && continue
    # frontmatter ブロック（1 つ目と 2 つ目の `---` の間）を抽出する。
    # sources / related が複数エントリでも取りこぼさないよう固定行数では切らない。
    # CRLF 改行でも破綻しないよう行末 CR を除去してから判定する。
    fm=$(awk '{ sub(/\r$/, "") } NR==1 && $0!="---"{exit} /^---$/{c++; if(c==2) exit; next} c==1' "$doc" 2>/dev/null) || continue
    for field in title sources updated; do
        if ! printf '%s\n' "$fm" | grep -q "^${field}:"; then
            fail "frontmatter の ${field} が無い: ${doc#"$target"/}"
            missing_fm=$((missing_fm + 1))
        fi
    done
done < <(find "$refs_root" -name '*.md' -type f -print0)
[ "$missing_fm" -eq 0 ] && pass "全ドキュメントに title / sources / updated がある"

# --- 5. 索引 CLAUDE.md とファイル実体の一致 ---
report "[5] 索引 CLAUDE.md とファイル実体の一致"
index_ng=0
while IFS= read -r -d '' dir; do
    idx="$dir/CLAUDE.md"
    [ -f "$idx" ] || { fail "索引が無い: ${dir#"$target"/}/CLAUDE.md"; index_ng=$((index_ng + 1)); continue; }
    for f in "$dir"/*.md; do
        [ -e "$f" ] || continue
        name=$(basename "$f")
        [ "$name" = "CLAUDE.md" ] && continue
        # -- でオプション終端を明示（ファイル名が - 始まりでも grep がオプション解釈しない）
        if ! grep -qF -- "$name" "$idx"; then
            fail "索引に未記載: ${dir#"$target"/}/${name}"
            index_ng=$((index_ng + 1))
        fi
    done
done < <(find "$refs_root" -type d ! -name archive -print0)
[ "$index_ng" -eq 0 ] && pass "各フォルダの索引がファイル実体と一致している"

# --- 6. 未置換プレースホルダ ---
# テンプレート由来のプレースホルダは日本語を含むため文字種を限定しない。
# mermaid の判断ノード記法（`A{条件}`）との誤検知を避けるため、
# フェンス付きコードブロックの内側は検査対象から除外する。
report "[6] 未置換プレースホルダ"
ph_files=""
while IFS= read -r -d '' doc; do
    # フェンス付きコードブロックとインラインコードスパン（`...`）は検査対象から除外する
    hit=$(awk '
        { sub(/\r$/, "") }
        /^[[:space:]]*```/ { fence = !fence; next }
        !fence {
            line = $0
            gsub(/`[^`]*`/, "", line)
            if (line ~ /\{[^{}]+\}/) { print NR; exit }
        }
    ' "$doc" 2>/dev/null)
    [ -n "$hit" ] && ph_files="${ph_files}${doc}:${hit}"$'\n'
done < <(find "$refs_root" -name '*.md' -type f -print0; [ -f "$harness_root/CLAUDE.md" ] && printf '%s\0' "$harness_root/CLAUDE.md")

if [ -n "$ph_files" ]; then
    while IFS= read -r entry; do
        [ -n "$entry" ] || continue
        fpath="${entry%:*}"
        fline="${entry##*:}"
        fail "未置換プレースホルダ: ${fpath#"$target"/}（${fline} 行目）"
    done <<< "$ph_files"
else
    pass "未置換プレースホルダなし"
fi

# --- 7. 秘匿値パターンの混入 ---
# パターンは authoring-spec.md 節 2 の表と対応させて維持する（表を変更したら本パターンも追随）。
# password/pwd の値部は ASCII 印字 4 文字以上に限定し、「password: 環境変数から取得」等の説明文を誤検出しない。
report "[7] 秘匿値パターン"
# password/pwd は大文字小文字を問わず検出する（DB_PASSWORD= 等の全大文字形を含む。authoring-spec 節 2 の宣言どおり）。
# 値部は「< で始まらない ASCII 印字 4 文字以上」に限定し、<REDACTED> / <設定値> と日本語説明文を誤検出しない。
secret_pat='(sk-[A-Za-z0-9]{16,}|gh[opusr]_[A-Za-z0-9]{20,}|xox[a-z]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|glpat-[A-Za-z0-9_-]{16,}|-----BEGIN [A-Z ]*(PRIVATE KEY|CERTIFICATE|PGP)|[Aa]uthorization:[[:space:]]*(Bearer|Basic)[[:space:]]+[A-Za-z0-9._~+/=-]{8,}|[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd][[:space:]]*[:=][[:space:]]*[^<[:space:]][A-Za-z0-9!-~]{3,}|[Pp][Ww][Dd][[:space:]]*[:=][[:space:]]*[^<[:space:]][A-Za-z0-9!-~]{3,})'
sec=$(grep -rlE "$secret_pat" "$refs_root" "$harness_root/CLAUDE.md" 2>/dev/null || true)
if [ -n "$sec" ]; then
    # ヒアストリングで回す（パイプのサブシェルだと violations 加算が失われるため）。1 ファイル = 1 違反として数える
    while IFS= read -r f; do
        [ -n "$f" ] && fail "秘匿値らしい記述: ${f#"$target"/}（該当記述を除去すること）"
    done <<< "$sec"
else
    pass "秘匿値パターンの混入なし"
fi

# --- 8. status フィールドの妥当値と整合（structure-spec.md 節 5.2 / authoring-spec.md 節 6 項目 10・11） ---
# status は任意フィールド。存在する場合のみ検査する（不在 = implemented 扱いで正常）。
report "[8] status フィールド"
status_ng=0
while IFS= read -r -d '' doc; do
    base=$(basename "$doc")
    [ "$base" = "CLAUDE.md" ] && continue
    fm=$(awk '{ sub(/\r$/, "") } NR==1 && $0!="---"{exit} /^---$/{c++; if(c==2) exit; next} c==1' "$doc" 2>/dev/null) || continue
    # キー重複は YAML パーサ（末尾優先が多い）と本検査（先頭採用）で解釈が割れるため、それ自体を NG とする
    scount=$(printf '%s\n' "$fm" | grep -c '^status:' || true)
    if [ "$scount" -gt 1 ]; then
        fail "frontmatter の status キーが重複（${scount} 件。1 件に統一すること）: ${doc#"$target"/}"
        status_ng=$((status_ng + 1))
        continue
    fi
    # 値の取得: 行末コメント・前後空白を除去し、YAML として正当なクォート（'draft' / "draft"）は剥がして判定する
    sval=$(printf '%s\n' "$fm" | sed -n 's/^status:[[:space:]]*//p' | head -n 1 | sed 's/[[:space:]]*#.*$//; s/[[:space:]]*$//' | sed "s/^'\(.*\)'$/\1/; s/^\"\(.*\)\"$/\1/")
    [ -z "$sval" ] && continue
    case "$sval" in
        draft|agreed|implemented) ;;
        *)
            # 不正値はレポートへ逐語転記しない（制御文字・埋め込み指示の混入経路になるため、印字可能文字のみ 32 文字まで）
            sval_safe=$(printf '%s' "$sval" | LC_ALL=C tr -cd '[:print:]' | cut -c1-32)
            fail "status の値が不正（draft / agreed / implemented のいずれか）: ${doc#"$target"/}（status: ${sval_safe}）"
            status_ng=$((status_ng + 1))
            continue
            ;;
    esac
    # implemented の定義は「sources 紐付け済み」のため、空の sources との組合せは実装追随の紐付け漏れ。
    # 空の判定は表記ゆれ（[] / [ ] / 行末コメント / 値なしで後続リスト項目なし）を含めて awk で行う
    if [ "$sval" = "implemented" ]; then
        src_state=$(printf '%s\n' "$fm" | awk '
            /^sources:[[:space:]]*\[[[:space:]]*\][[:space:]]*(#.*)?$/ { print "empty"; done = 1; exit }
            /^sources:[[:space:]]*(#.*)?$/ { key = 1; next }
            key == 1 && /^[[:space:]]*$/ { next }
            key == 1 { if ($0 ~ /^[[:space:]]+-[[:space:]]*[^[:space:]]/) print "list"; else print "empty"; done = 1; exit }
            END { if (key == 1 && !done) print "empty" }
        ')
        if [ "$src_state" = "empty" ]; then
            fail "status: implemented だが sources が空（実装追随の紐付け漏れ）: ${doc#"$target"/}"
            status_ng=$((status_ng + 1))
        fi
    fi
done < <(find "$refs_root" -name '*.md' -type f -print0)
[ "$status_ng" -eq 0 ] && pass "status フィールドは妥当（不在 = implemented 扱い）"

report ""
if [ "$violations" -eq 0 ]; then
    report "検証結果: 全項目合格"
    exit 0
fi
report "検証結果: ${violations} 件の違反を検出"
exit 1
