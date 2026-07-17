# Azure DevOps PR 操作 — オンプレ TFS Server (NTLM 認証)

> **本ファイルは connector:azure の内部実装リファレンス（デバッグ・トラブルシューティング用）として維持する。pr-review からの直接 API 実行は廃止され、すべて `connector:azure` 経由で操作する。** pr-review の投稿フローは `comment-posting.md` セクション 7.2 を参照。

`pr-review` スキルが **オンプレ Azure DevOps Server (TFS)** の PR を扱う際のコマンド・REST API 詳細。

> **位置付け**: 旧 `azure-devops.md` の 1.x セクションから分離。クラウド ADO は `azure-devops-cloud.md`、共通仕様（status 値・URL 解析・レート制限）は `azure-devops-common.md` を参照。

> **重要な制約**: `az devops` 拡張は実行時に `WARNING: The Azure DevOps Extension for the Azure CLI does not support Azure DevOps Server.` を出すため、**オンプレ TFS では `az devops invoke` / `az repos pr` 等の az コマンドは使用不可**。REST API を `curl --ntlm` で直接呼ぶ。

---

## 1. 認証セットアップ

オンプレ TFS は **既存の Windows ドメイン認証**（NTLM）で動作する。**PAT も MS アカウントも不要**。

> **認証情報ストアの前提（U12）**: `tfs-password` エントリの登録先は **credentials-manager プラグインの標準ストア** `.claude/.local/plugins/credentials-manager/credentials.json`（リポジトリ優先 → ホーム）。connector（本ファイルが解説する内部実装）が **このストア + 後方互換の従来パス `~/.claude/credentials.json`** を横断して解決する。登録はユーザーが credentials-manager プラグイン経由で行う。以下の `jq ... ~/.claude/credentials.json` は connector 内部の単一ストア読取りを簡略に示す例で、connector 実体は複数ストアを解決する。

```bash
# 事前準備（初回のみ・手動）:
#   credentials-manager プラグインで "tfs-password" エントリを登録（標準ストア
#   .claude/.local/plugins/credentials-manager/credentials.json に保存される）:
#     username, value (パスワード), urls: ["https://<host>/*"], domains: ["<host>"], auth_method: "ntlm:<username>"
#   未設定で pr-review スキルを起動した場合は、最初にユーザーへ問い合わせる。

# 利用時：環境変数経由で取得（コマンドライン引数に出さない・null 文字列を弾く）
export TFS_HOST=<TFS ホスト名>   # 例: tfs.example.com（pr-review SKILL.md の登録方法に従って解決）
# credentials-manager 標準ストアを解決（リポジトリ優先 → ホーム。後方互換で従来パスも）。
# connector 実体は同等の複数ストア解決を行う（本例は簡略化した単一ストア読取り）
CRED_STORE="$(git rev-parse --show-toplevel 2>/dev/null)/.claude/.local/plugins/credentials-manager/credentials.json"
[ -f "$CRED_STORE" ] || CRED_STORE="$HOME/.claude/.local/plugins/credentials-manager/credentials.json"
[ -f "$CRED_STORE" ] || CRED_STORE="$HOME/.claude/credentials.json"  # 後方互換（従来パス）
export TFS_USER=$(jq -r '.credentials["tfs-password"].username // empty' "$CRED_STORE")
# username フィールドが空でも auth_method が "ntlm:<user>" / "basic:<user>" 形式なら
# そこからユーザー名を抽出する（credentials-manager の登録形式によっては
# username が空で auth_method 側にのみ含まれるケースがあるため）
if [ -z "$TFS_USER" ]; then
  AUTH=$(jq -r '.credentials["tfs-password"].auth_method // empty' "$CRED_STORE")
  case "$AUTH" in
    ntlm:*|basic:*) export TFS_USER="${AUTH#*:}" ;;
  esac
fi
export TFS_PASS=$(jq -r '.credentials["tfs-password"].value // empty' "$CRED_STORE")
[ -z "$TFS_HOST" ] && { echo "ERROR: TFS_HOST が未設定"; exit 1; }
[ -z "$TFS_USER" ] && { echo "ERROR: tfs-password の username も auth_method=ntlm:<user> も credentials.json に未設定"; exit 1; }
[ -z "$TFS_PASS" ] && { echo "ERROR: tfs-password.value が credentials.json に未設定"; exit 1; }
```

---

## 2. `.netrc` 経由の安全な呼び出し（必須パターン）

**コマンドライン引数に PASS を渡すと `ps` / Sysmon EventID 1 / EDR ログから漏洩**するため、必ず `.netrc` ファイル経由で渡す。

```bash
# クリーンアップ関数を定義（trap の責務を明確化・複数リソース対応）
# 一時ファイル変数は事前 null 初期化することで、未定義時に rm -f "" が
# 意図せずカレントディレクトリのファイルを削除するリスクを防ぐ
NETRC=""; BODY=""; RESP=""; CONTENT_FILE=""; PATH_FILE=""
cleanup_secrets() {
  rm -f "${NETRC:-}" "${BODY:-}" "${RESP:-}" "${CONTENT_FILE:-}" "${PATH_FILE:-}" 2>/dev/null || true
}

# (必須) NETRC 書き込み前に $TFS_HOST が credentials.json のホワイトリストに含まれるか検証
# 攻撃者が CLAUDE.md / 引数経由で偽 TFS_HOST を渡し NTLM 認証情報を外部に
# 送信する SSRF / NTLM relay 経路を構造的に塞ぐ
ALLOWED_HOSTS=$(jq -r '
  .credentials["tfs-password"].urls[]?
  | capture("https?://(?<h>[^/]+)").h
' "$CRED_STORE" 2>/dev/null)  # $CRED_STORE はセクション 1 で解決済み（credentials-manager 標準ストア）
if [ -z "$ALLOWED_HOSTS" ]; then
  echo "ERROR: credentials.json の tfs-password.urls[] が未設定です"; exit 1
fi
if ! printf '%s\n' "$ALLOWED_HOSTS" | grep -Fxq "$TFS_HOST"; then
  echo "ERROR: \$TFS_HOST=$TFS_HOST は credentials.json の許可ホスト一覧に含まれません"
  echo "       許可ホスト: $ALLOWED_HOSTS"
  exit 1
fi

# trap は mktemp より先に張る（先張り）。間にシグナルを受けても変数が空文字なら
# rm -f "" で何も削除しないため安全。逆順（mktemp → trap）にすると、
# その間のシグナルで一時ファイルが残るウィンドウが生じる
trap cleanup_secrets EXIT INT TERM HUP QUIT
NETRC=$(mktemp); chmod 600 "$NETRC"
printf 'machine %s\nlogin %s\npassword %s\n' "$TFS_HOST" "$TFS_USER" "$TFS_PASS" > "$NETRC"

# .netrc 書き込み後はメモリ上の PASS を即座に消す（環境変数経由の漏洩面を最小化）
unset TFS_PASS

# NTLM 認証で REST API を呼ぶ（HTTP コード取得 + case 分岐は http-error-handling.md セクション 3 を適用）
RESP=$(mktemp); chmod 600 "$RESP"
HTTP_CODE=$(curl -sS --max-time 30 --ntlm --netrc-file "$NETRC" \
  -H "Accept: application/json" \
  -o "$RESP" -w '%{http_code}' \
  "https://${TFS_HOST}/tfs/<collection>/<project>/_apis/git/repositories/<repo>/pullrequests?api-version=6.0&searchCriteria.status=active")
[[ "$HTTP_CODE" =~ ^2 ]] || { echo "HTTP $HTTP_CODE"; head -c 300 "$RESP"; exit 1; }
```

> `curl -sS --max-time 30 ... -o "$RESP" -w '%{http_code}'`: プログレス抑制 (`-s`) + エラー表示 (`-S`) + 出力ファイル (`-o`) + HTTP コード取得 (`--write-out`)。`-fsSL` は HTTP エラーで非ゼロ終了するが 401/403/429/5xx の判別ができないため使わない（SSOT: `${CLAUDE_PLUGIN_ROOT}/references/http-error-handling.md` セクション 3）。
>
> `cleanup_secrets` 関数化により、後段で `$BODY` `$RESP` `$CONTENT_FILE` `$PATH_FILE` を追加しても trap を再設定する必要がなく、シグナル受信時に確実に削除できる。
>
> **URL ホワイトリスト検証は必須**: `$TFS_HOST` の値が引数や CLAUDE.md 等から渡される場合、そのまま NTLM 認証付きリクエストを送ると `evil.example.com/tfs/...` のような攻撃者制御ホストへ NTLM ハッシュを送信するリスクがある。本検証で `credentials.json` 登録済みホストのみに制限する。

---

## 3. PR 一覧取得

```bash
# HTTP コード取得 + case 分岐は http-error-handling.md セクション 3 を適用
HTTP_CODE=$(curl -sS --max-time 30 --ntlm --netrc-file "$NETRC" \
  -H "Accept: application/json" \
  -o "$RESP" -w '%{http_code}' \
  "https://${TFS_HOST}/tfs/<collection>/<project>/_apis/git/repositories/<repo>/pullrequests?api-version=6.0&searchCriteria.status=active")
[[ "$HTTP_CODE" =~ ^2 ]] || { echo "HTTP $HTTP_CODE"; head -c 300 "$RESP"; exit 1; }
jq -r '.value[] | "PR #\(.pullRequestId): \(.title) (\(.status))"' < "$RESP"
```

---

## 4. PR 詳細・差分

```bash
# PR 詳細（HTTP コード取得 + case 分岐は http-error-handling.md セクション 3 を適用）
HTTP_CODE=$(curl -sS --max-time 30 --ntlm --netrc-file "$NETRC" \
  -o "$RESP" -w '%{http_code}' \
  "https://${TFS_HOST}/tfs/<collection>/<project>/_apis/git/repositories/<repo>/pullrequests/<N>?api-version=6.0")
[[ "$HTTP_CODE" =~ ^2 ]] || { echo "HTTP $HTTP_CODE"; head -c 300 "$RESP"; exit 1; }

# PR 差分（git で取得）
git fetch origin <sourceRefName>:<sourceBranch>
git fetch origin <targetRefName>:<targetBranch>
git diff <targetBranch>...<sourceBranch>
```

---

## 5. スレッド取得・ステータス更新

```bash
# スレッド一覧（HTTP コード取得 + case 分岐は http-error-handling.md セクション 3 を適用）
HTTP_CODE=$(curl -sS --max-time 30 --ntlm --netrc-file "$NETRC" \
  -o "$RESP" -w '%{http_code}' \
  "https://${TFS_HOST}/tfs/<collection>/<project>/_apis/git/repositories/<repo>/pullrequests/<N>/threads?api-version=6.0")
[[ "$HTTP_CODE" =~ ^2 ]] || { echo "HTTP $HTTP_CODE"; head -c 300 "$RESP"; exit 1; }

# スレッドステータス更新（fixed に変更）
BODY=$(mktemp); chmod 600 "$BODY"
# cleanup_secrets 関数（セクション 2 で定義）が EXIT 時に NETRC / BODY / RESP / CONTENT_FILE / PATH_FILE を削除する
jq -n '{status: "fixed"}' > "$BODY"

# HTTP コード取得 + case 分岐は http-error-handling.md セクション 3 を適用
HTTP_CODE=$(curl -sS --max-time 30 -X PATCH --ntlm --netrc-file "$NETRC" \
  -H "Content-Type: application/json" \
  --data-binary "@$BODY" \
  -o "$RESP" -w '%{http_code}' \
  "https://${TFS_HOST}/tfs/<collection>/<project>/_apis/git/repositories/<repo>/pullrequests/<N>/threads/<threadId>?api-version=6.0")
[[ "$HTTP_CODE" =~ ^2 ]] || { echo "HTTP $HTTP_CODE"; head -c 300 "$RESP"; exit 1; }
```

---

## 6. インラインコメント追加（新規スレッド）

> **重要（Windows Git Bash 環境）**: 値の渡し方は **`--rawfile`（一時ファイル経由）** を使うこと。`--arg "/path"` は MSYS パス自動変換で `C:/Program Files/Git/path` に化け、`SOMEVAR="$utf8" jq -n env.SOMEVAR` の env 経由は Windows ネイティブ jq.exe が CP932 で読み UTF-8 が U+FFFD に化ける。`--rawfile` は両方を回避する。

```bash
# 値を UTF-8 でファイルに書き出してから --rawfile で渡す（CP932 化を回避）
CONTENT_FILE=$(mktemp); chmod 600 "$CONTENT_FILE"
PATH_FILE=$(mktemp); chmod 600 "$PATH_FILE"
printf '%s' "$comment_body" > "$CONTENT_FILE"
# 二重スラッシュ //plugins/... で MSYS 変換を回避し、jq 内で sub で / 1 個に正規化
printf '%s' "//${file_path#/}" > "$PATH_FILE"

BODY=$(mktemp); chmod 600 "$BODY"
# cleanup_secrets 関数（セクション 2）に CONTENT_FILE, PATH_FILE, BODY を含めること

jq -n \
  --rawfile content "$CONTENT_FILE" \
  --rawfile path    "$PATH_FILE" \
  --argjson start_line <開始行> \
  --argjson end_line   <終了行> \
  '{
    comments: [{ parentCommentId: 0, content: $content, commentType: 1 }],
    status: "active",
    threadContext: {
      filePath: ($path | sub("^//"; "/")),
      rightFileStart: { line: $start_line, offset: 1 },
      rightFileEnd:   { line: $end_line,   offset: 1 }
    }
  }' > "$BODY"

# HTTP コード取得 + case 分岐は http-error-handling.md セクション 3 を適用
HTTP_CODE=$(curl -sS --max-time 30 -X POST --ntlm --netrc-file "$NETRC" \
  -H "Content-Type: application/json" \
  --data-binary "@$BODY" \
  -o "$RESP" -w '%{http_code}' \
  "https://${TFS_HOST}/tfs/<collection>/<project>/_apis/git/repositories/<repo>/pullrequests/<N>/threads?api-version=6.0")
[[ "$HTTP_CODE" =~ ^2 ]] || { echo "HTTP $HTTP_CODE"; head -c 300 "$RESP"; exit 1; }
```

---

## 7. 既存スレッドへの reply（再レビュー時の主操作）

修正後の再レビューでは **新規スレッドではなく既存スレッドに reply** を入れる（`pr-review/SKILL.md` Step 4 / 5、`re-review-flow.md` 参照）。

```bash
# parentCommentId は対象スレッドの最初のコメント id（通常は 1）
CONTENT_FILE=$(mktemp); chmod 600 "$CONTENT_FILE"
printf '%s' "$reply_body_md" > "$CONTENT_FILE"

BODY=$(mktemp); chmod 600 "$BODY"

jq -n \
  --rawfile content "$CONTENT_FILE" \
  --argjson parent  "$parent_comment_id" \
  '{content: $content, parentCommentId: $parent, commentType: 1}' > "$BODY"

# threadId は数値であることを正規表現で検証してから使う
[[ "$thread_id" =~ ^[0-9]+$ ]] || { echo "invalid threadId"; exit 1; }

# HTTP コード取得 + case 分岐は http-error-handling.md セクション 3 を適用
HTTP_CODE=$(curl -sS --max-time 30 -X POST --ntlm --netrc-file "$NETRC" \
  -H "Content-Type: application/json" \
  --data-binary "@$BODY" \
  -o "$RESP" -w '%{http_code}' \
  "https://${TFS_HOST}/tfs/<collection>/<project>/_apis/git/repositories/<repo>/pullrequests/<N>/threads/${thread_id}/comments?api-version=6.0")
[[ "$HTTP_CODE" =~ ^2 ]] || { echo "HTTP $HTTP_CODE"; head -c 300 "$RESP"; exit 1; }
```

reply 投稿後、解消パターン (Pattern A) であれば セクション 5 の status 更新（`{"status":"fixed"}`）を続けて呼ぶ。Pattern C では status は変更しない。

---

## 8. 自著判定（NTLM 認証時）

NTLM の `uniqueName` 3 形式（`DOMAIN\username` / `username@domain` / `username` 単体）への対応・空文字ガード・大文字小文字無視比較等の **詳細実装は `${CLAUDE_SKILL_DIR}/references/author-identity.md` セクション 2 を参照**。

> ⚠️ **`displayName` での比較は禁止**。常に `uniqueName`（GUID または UPN または `DOMAIN\username` 形式）を使う。空文字ガードを **必ず** 入れること（両方空文字での誤一致防止）。

---

## 関連リファレンス

- `azure-devops-cloud.md` — クラウド Azure DevOps（MS アカウント / az devops）
- `azure-devops-common.md` — 共通仕様（status 値・commentType・URL 解析・レート制限）
- `re-review-flow.md` — 再レビュー時の動作仕様（reply 用 API はセクション 7 を使う）
- `author-identity.md` — 自著判定の詳細実装
