# 外部リソース fetch の安全方針（プラグイン共通）

`deep-code-review` プラグイン内のすべてのスキル（pr-review / code-review-* / env-setup / 将来拡張スキル）が **外部 URL を自動取得する際に共通で適用する SSRF / 認証情報漏洩対策**。

> **位置付け**: 本ファイルは `${CLAUDE_PLUGIN_ROOT}/references/safe-external-fetch.md`（プラグイン直下 references）に配置されており、各スキルから参照される。スキル個別の references 配下に同じ対策を重複実装してはならない。

---

## 0. 適用範囲

以下のいずれかの操作を行うすべてのスキルに適用:

- WebFetch ツールで外部 URL を取得する
- `curl` / `wget` で外部 URL を取得する
- 外部 API を叩いて結果を取り込む
- リダイレクト先を追跡する

---

## 1. ドメインホワイトリスト方式（必須）

### 1.1 原則

外部 URL の自動 fetch は **credentials-manager プラグインの認証情報ストアの `domains` / `urls` に登録されているホスト** のみ許可する（U12: 認証情報の源泉は credentials-manager ストアを前提とする）。ストアのパスは `.claude/.local/plugins/credentials-manager/credentials.json`（リポジトリ優先 → ホーム。後方互換で従来パス `~/.claude/credentials.json` も参照）。

### 1.2 判定ロジック

1. 抽出した URL からホスト部分を取り出す
2. `credentials.json` の各エントリの `domains[]` または `urls[]` のホスト部と完全一致を確認
3. 一致するエントリがある → 当該エントリの `auth_method` で認証を付与して fetch
4. 一致しない → **自動 fetch しない**。ユーザーに「資料が記載されているが認証情報未登録」と報告し、手動提供を求める

### 1.3 抽出ロジック例

```bash
# URL からホスト抽出
URL="$1"
HOST=$(printf '%s' "$URL" | sed -E 's#^https?://([^/]+)/.*#\1#' | tr '[:upper:]' '[:lower:]')

# credentials-manager ストアの登録ホスト一覧
# ストア解決: リポジトリ優先 → ホーム（後方互換で従来パスも）。connector と同じストアを参照する
CRED_STORE="$(git rev-parse --show-toplevel 2>/dev/null)/.claude/.local/plugins/credentials-manager/credentials.json"
[ -f "$CRED_STORE" ] || CRED_STORE="$HOME/.claude/.local/plugins/credentials-manager/credentials.json"
[ -f "$CRED_STORE" ] || CRED_STORE="$HOME/.claude/credentials.json"  # 後方互換（従来パス）
ALLOWED=$(jq -r '
  .credentials | to_entries[] | .value
  | (.domains[]?, (.urls[]? | capture("https?://(?<h>[^/]+)").h))
' "$CRED_STORE" | tr '[:upper:]' '[:lower:]' | sort -u)

if ! printf '%s\n' "$ALLOWED" | grep -Fxq "$HOST"; then
  echo "ERROR: $HOST は credentials.json に登録されていません。fetch をスキップします"
  return 1
fi
```

これにより:

- 攻撃者が PR description に `https://attacker.example/track?leak=...` を仕込んでも fetch されない
- 認証情報を意図しないホストへ送信する事故を防げる

---

## 2. 内部 IP / メタデータ IMDS の明示的拒否（必須）

ホワイトリスト一致前であっても、以下のホストは **常に拒否** する:

| 種別 | 範囲・ホスト |
|------|------------|
| ループバック | `localhost` / `127.0.0.0/8` / `::1` |
| クラウド IMDS | `169.254.169.254` / `fd00:ec2::254` / `metadata.google.internal` / `metadata.azure.com` |
| プライベート IPv4 | `10.0.0.0/8` / `172.16.0.0/12` / `192.168.0.0/16` |
| リンクローカル | `169.254.0.0/16` / `fe80::/10` |

社内サーバが TFS / Wiki でこの帯にある場合は、`credentials.json` で **明示的に登録** することで例外的に許可する（ホワイトリスト方式と整合）。

### 2.1 検証実装

> **ツール層強制（推奨・spec-inference で採用）**: raw `curl` を直接使わず、ガードスクリプト **`${CLAUDE_PLUGIN_ROOT}/references/scripts/fetch/safe_fetch.sh <url> <allowed_hosts_csv>`** 経由で取得する。スクリプトが本セクションのホワイトリスト照合・内部 IP 拒否・IP ピン留め・上限を一括で強制するため、`allowed-tools` を `Bash(bash ${CLAUDE_PLUGIN_ROOT}/references/scripts/fetch/*.sh *)` に限定すれば SSRF 経路をツール層で排除できる。以下は同スクリプトが内部で行う検証と同等の参考実装:

`curl` を投げる前に正規表現 + IP 解決で行う:

```bash
# 名前解決 (Windows: nslookup / Unix: getent ahosts)
if command -v getent > /dev/null; then
  IPS=$(getent ahosts "$HOST" | awk '{print $1}' | sort -u)
elif command -v nslookup > /dev/null; then
  IPS=$(nslookup "$HOST" 2>/dev/null | awk '/^Address/ && !/#/ {print $NF}')
fi

# 拒否範囲との照合
# 0.0.0.0/8・ループバック・私設・リンクローカル・IMDS・IPv4-mapped IPv6・ULA(fc00::/7) を拒否
DENY_REGEX='^(0\.|127\.|10\.|192\.168\.|169\.254\.|::1$|::ffff:|fe80:|f[cd][0-9a-f][0-9a-f]:|172\.(1[6-9]|2[0-9]|3[01])\.)'
for ip in $IPS; do
  if printf '%s' "$ip" | grep -Eq "$DENY_REGEX"; then
    echo "ERROR: $HOST → $ip は拒否範囲に含まれます (内部 IP / IMDS)"
    return 1
  fi
done
```

> **IP 表記の正規化（必須）**: ホスト部が 10 進整数（`2130706433`）・8 進（`0177.0.0.1`）・16 進（`0x7f000001`）・短縮 IPv6 で与えられた場合、DENY_REGEX 照合の **前に** ドット付き 10 進へ正規化する（例: `getent hosts` / `python3 -c 'import ipaddress; print(ipaddress.ip_address(int(...)))'`）。正規化しないと数値表記の内部 IP がホワイトリスト二次防御をすり抜ける。

> **DNS rebinding / TOCTOU 対策（必須）**: 上記の IP 照合（解決時）と実際の `curl` 接続時で再解決した IP が異なる rebinding 攻撃を防ぐため、照合済み IP を `curl --resolve <host>:<port>:<ip>` でピン留めして接続する（照合した IP と実接続 IP を一致させる）。ホワイトリスト適合ホストが前提のため成立条件は限定的だが、多層防御として実施する。

---

## 3. リクエスト制限（必須）

| 制限 | 値 | 目的 |
|------|---|------|
| タイムアウト | 30 秒（`curl --max-time 30`） | DoS 防止・無限待機防止 |
| サイズ上限 | 1 MB（`curl --max-filesize 1048576`） | メモリ枯渇・大量データ取り込み防止 |
| リダイレクト数 | 最大 3 ホップ（`-L --max-redirs 3`） | 無限リダイレクト防止 |
| **リダイレクト先のホワイトリスト再チェック** | 必須 | 攻撃者がホワイトリスト内 → 外部へリダイレクトする経路を防ぐ |

### 3.1 リダイレクト先再検証

```bash
# 最終 URL を取得して再度ホワイトリスト検証
FINAL_URL=$(curl -sS -o /dev/null -w '%{url_effective}' \
  --max-time 30 --max-filesize 1048576 -L --max-redirs 3 \
  "$URL")
# FINAL_URL を再度 ホワイトリスト検証 + IP 拒否範囲検証 にかける
```

---

## 4. 取得結果のサニタイズ（必須）

外部資料の取得結果を PR コメント本文等に転載する際は、本プラグイン共通の
`${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` のサニタイズパターン
（Bearer / GHP / JWT / Basic / 外部画像 / `javascript:` 等の伏字化）を **必ず適用する**。

無加工転載は XSS / 機密情報混入リスクがあるため禁止。

---

## 5. dry-run（既定動作の推奨）

各スキルで「fetch 候補一覧」を提示してユーザー承認を得る dry-run を **既定動作として推奨**。CI/CD 用途で確認をスキップする場合は明示的なフラグ（例: `fetch-external=auto`）を要求する。

---

## 6. 禁止事項（共通）

- ホワイトリスト未登録のドメインへ自動 fetch すること
- 認証情報を URL クエリで送る際の URL を **そのままログに残す** こと（マスキング必須）
- 内部 IP / IMDS / プライベート IP レンジへ自動 fetch すること
- 外部資料の取得結果を **無加工で PR コメントに転載** すること（サニタイズ必須）
- 取得サイズ無制限・タイムアウト無制限で fetch すること
- リダイレクト先のホワイトリスト再検証を省略すること

---

## 7. 適用契約

本ファイルは **プラグイン共通の SSRF / 認証情報漏洩対策** を規定する。
外部 URL を fetch する個別スキルは、本ファイルの規定（ドメインホワイトリスト・内部 IP 拒否・タイムアウト/サイズ制限・リダイレクト再検証・サニタイズ・禁止事項）に準拠を宣言したうえで利用すること。

依存方向（共通 references から個別スキルへの参照を持たない一方向）の SSOT は同ディレクトリ `CLAUDE.md`「原則」。
