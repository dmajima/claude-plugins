# 自著判定（Author Identity Resolution）

`pr-review` スキルが PR スレッド/コメントの **起票者（自著）** を判定するための共通ロジック。GitHub / クラウド Azure DevOps / オンプレ TFS で **形式が異なる** ため、本ファイルに集約する。

> **重要**: 自動 resolve / 自動 reply の対象を「自分が起票したスレッド」に限定するための判定基盤。**`displayName` での比較は禁止**（表示名は変更可能・一意性なし）。常に `uniqueName` / `login` / `id` 等の **一意識別子** を使う。

---

## 1. 共通方針（必須）

すべてのホストで以下を遵守する:

| 原則 | 内容 |
|------|------|
| **使用フィールド** | `uniqueName`（Azure DevOps）、`login`（GitHub）、または `id`（GUID） |
| **使用禁止** | `displayName`（表示名は変更可能・一意性なし） |
| **大文字小文字** | `tolower` 正規化して比較（`tr '[:upper:]' '[:lower:]'`） |
| **空文字ガード（必須）** | 認証ユーザー名 or スレッド作者の値が空文字の場合は **判定スキップ → 未解決として保守的に残す**。両方空で `[ "" = "" ]` が真になる誤一致を防ぐ |
| **失敗時の挙動** | 判定不能なら自動操作（resolve / fixed / status 変更）を一切行わない |

---

## 2. オンプレ TFS Server / NTLM 認証（`uniqueName` の 3 形式に対応）

NTLM 認証では `comments[0].author.uniqueName` の形式が複数あり得るため、3 形式すべてに対応する:

| 形式 | 例 | username 抽出 |
|------|------|-------------|
| `DOMAIN\username` | `CONTOSO\jdoe` | `${val##*\\}` |
| `username@domain.com`（UPN 形式） | `jdoe@contoso.example.com` | `${val%%@*}` |
| `username` 単体 | `jdoe` | そのまま |

```bash
# === 自著判定（NTLM 用） ===
AUTHOR_UNIQUENAME=$(echo "$thread_json" | jq -r '.comments[0].author.uniqueName // ""')

# 形式に応じて username 部分を抽出
if [[ "$AUTHOR_UNIQUENAME" == *"\\"* ]]; then
  AUTHOR_USER="${AUTHOR_UNIQUENAME##*\\}"   # DOMAIN\username
elif [[ "$AUTHOR_UNIQUENAME" == *"@"* ]]; then
  AUTHOR_USER="${AUTHOR_UNIQUENAME%%@*}"    # username@domain
else
  AUTHOR_USER="$AUTHOR_UNIQUENAME"          # username 単体
fi

# 大文字小文字を無視して比較
ME=$(echo "$TFS_USER" | tr '[:upper:]' '[:lower:]')
AUTHOR=$(echo "$AUTHOR_USER" | tr '[:upper:]' '[:lower:]')

# 空文字ガード（必須）
if [ -z "$ME" ] || [ -z "$AUTHOR" ]; then
  echo "WARN: 認証ユーザーまたはスレッド作者の uniqueName が空。自著判定スキップ → 未解決のまま残す"
  return 1   # または continue
fi

if [ "$ME" = "$AUTHOR" ]; then
  echo "自著スレッド → resolve 候補"
fi
```

> NTLM の `displayName` は人間が変更可能。常に `uniqueName` を使い、空文字ガードを通す。

---

## 3. クラウド Azure DevOps / MS アカウント（UPN 形式）

クラウドでは `comments[0].author.uniqueName` は **UPN 形式（`user@example.com`）固定**。`az account show --query user.name -o tsv` の値と **大文字小文字を無視して** 比較する。

```bash
# === 自著判定（クラウド ADO 用） ===
ME=$(az account show --query user.name -o tsv | tr '[:upper:]' '[:lower:]')
AUTHOR=$(echo "$thread_json" | jq -r '.comments[0].author.uniqueName // ""' | tr '[:upper:]' '[:lower:]')

# 空文字ガード（必須）
if [ -z "$ME" ] || [ -z "$AUTHOR" ]; then
  echo "WARN: 認証ユーザーまたはスレッド作者の uniqueName が空。自著判定スキップ"
  return 1
fi

if [ "$ME" = "$AUTHOR" ]; then
  echo "自著スレッド → resolve 候補"
fi
```

---

## 4. GitHub（`login` フィールド）

GitHub では `comments[0].author.login`（GraphQL）または `user.login`（REST）を使う。`gh api user --jq .login` の値と比較。GitHub の login は大文字小文字を保持するが、ユニーク性は **大文字小文字無視で保証** されるため `tolower` 正規化を行う。

```bash
# === 自著判定（GitHub 用） ===
ME=$(gh api user --jq .login | tr '[:upper:]' '[:lower:]')
AUTHOR=$(echo "$thread_json" | jq -r '.comments[0].author.login // ""' | tr '[:upper:]' '[:lower:]')

# 空文字ガード
if [ -z "$ME" ] || [ -z "$AUTHOR" ]; then
  echo "WARN: 認証ユーザーまたはスレッド作者の login が空。自著判定スキップ"
  return 1
fi

if [ "$ME" = "$AUTHOR" ]; then
  echo "自著スレッド → resolve 候補"
fi
```

---

## 5. 共通の禁止事項

- ❌ `displayName` での比較（表示名変更可能・一意性なし・なりすまし可能）
- ❌ 空文字ガードなしの一致判定（両方空で `[ "" = "" ]` が真になる誤一致）
- ❌ 大文字小文字を無視せずに比較（`Jdoe` と `jdoe` を別人扱いする誤判定）
- ❌ NTLM の 3 形式（`DOMAIN\user` / `user@domain` / `user`）のうち 1 形式しか考慮しない実装

---

## 6. 関連リファレンス

- `pr-review/references/comment-status.md` — 自著限定の安全方針（セクション 0.2）
- `pr-review/references/azure-devops-tfs-ntlm.md` — NTLM の認証セットアップ + reply API
- `pr-review/references/azure-devops-cloud.md` — クラウド ADO の認証セットアップ + API
- `pr-review/references/github.md` — GitHub PR 操作の詳細
