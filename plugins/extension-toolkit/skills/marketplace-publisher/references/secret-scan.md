# シークレットスキャン仕様

公開対象プラグインにシークレット（API キー・トークン・秘密鍵・`.env` 等）が混入していないかを `git add` 前に検査する仕組み。`marketplace-publisher` の「2. プラグイン実体検証」フェーズで **必須** の検査として実行する。

## 設計方針

- **fail-closed**: 検出時は公開フローを中断し、ユーザの明示的な対応を待つ
- **二重検査**: ファイル名パターンと内容パターンの両方を実施
- **過検出許容**: 誤検出よりも漏れを許さない（false positive はユーザ確認で除外可能）
- **スコープ限定**: スキャン対象は `plugins/{plugin-name}/` 配下に限定（履歴・他プラグインを巻き込まない）

## 1. ファイル名パターン

以下のパターンに合致するファイルを検出する。

| パターン | 例 |
|---------|-----|
| `*.env` / `.env*` | `.env`, `.env.local`, `production.env` |
| `*.pem` | `private.pem`, `cert.pem` |
| `*.key` | `id_rsa`, `aws.key`, `*.private.key` |
| `id_rsa` / `id_dsa` / `id_ecdsa` / `id_ed25519` | SSH 秘密鍵 |
| `credentials.json` / `credentials.yaml` | クラウド認証情報 |
| `secrets.json` / `secrets.yaml` / `secrets.yml` | アプリ秘匿設定 |
| `*.p12` / `*.pfx` | PKCS#12 証明書 |
| `*.kdbx` | KeePass DB |
| `.netrc` / `_netrc` | HTTP 認証情報 |
| `.htpasswd` / `*.htpasswd` | Apache 認証ファイル |
| `*.secret` / `*-secret` | 一般的なシークレット命名 |
| `.aws/credentials` / `.azure/credentials` | クラウド認証情報 |

### 除外（false positive 抑制）

- `*.example` / `*.sample` / `*.template` サフィックスは除外
- `README.md` 等のドキュメント内で「シークレットを置かないこと」の説明は内容スキャンで除外（後述）

## 2. 内容パターン

各テキストファイル（バイナリ除く）の中身を以下の正規表現で検査する。

| 種別 | 正規表現 |
|-----|---------|
| AWS アクセスキー ID | `AKIA[0-9A-Z]{16}` |
| AWS シークレットアクセスキー | `aws_secret_access_key\s*=\s*["']?[A-Za-z0-9/+=]{40}["']?` |
| GitHub Personal Access Token | `ghp_[A-Za-z0-9]{36}` |
| GitHub OAuth Token | `gho_[A-Za-z0-9]{36}` |
| GitHub User-to-server Token | `ghu_[A-Za-z0-9]{36}` |
| GitHub Server-to-server Token | `ghs_[A-Za-z0-9]{36}` |
| GitHub Refresh Token | `ghr_[A-Za-z0-9]{36}` |
| Slack Token | `xox[baprs]-[0-9A-Za-z-]{10,}` |
| Google API Key | `AIza[0-9A-Za-z\-_]{35}` |
| Stripe Secret Key | `sk_live_[0-9a-zA-Z]{24,}` |
| Anthropic API Key | `sk-ant-[A-Za-z0-9\-_]{20,}` |
| OpenAI API Key | `sk-[A-Za-z0-9]{48}` |
| 秘密鍵（PEM ヘッダー） | `-----BEGIN (RSA \|EC \|OPENSSH \|DSA \|PGP \|)PRIVATE KEY-----` |
| Generic Bearer Token | `Bearer\s+[A-Za-z0-9\-_=]{20,}` |
| Generic Password 代入（クォート任意） | `(?i)(password\|passwd\|secret\|api[-_]?key)\s*[:=]\s*["']?([^"'\s]{8,})["']?` |
| JWT | `eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+` |
| Azure Storage Key | `DefaultEndpointsProtocol=https;AccountName=[A-Za-z0-9]+;AccountKey=[A-Za-z0-9+/=]+` |
| Azure SAS Token | `sig=[A-Za-z0-9%]+(&|$)` |

## 3. 検出時の動作（fail-closed）

検出された場合、`marketplace-publisher` は **公開フローを中断** し、以下のメッセージをユーザに提示する:

```text
シークレット混入の疑いを検出しました。公開フローを中断します。

検出ファイル:
- {ファイルパス} — {検出理由（パターン名）}
- ...

どう対応しますか？
1. 該当ファイルを削除/移動してから再実行
2. .gitignore に追加してから再実行
3. 誤検出として続行（ユーザ責任で実行、再確認を要求）
4. キャンセル
```

選択肢の提示は `AskUserQuestion`（[`../../../references/user-interaction.md`](../../../references/user-interaction.md)）を用いる。
「3. 誤検出として続行」は二重確認（"本当に公開してよいか？" の追加質問）を必ず行う。

## 4. 実装ヒント

擬似コード（参考実装）:

```python
import re, pathlib

# ファイル名は完全一致（fullmatch）で評価する
FILE_PATTERNS_FULL = [
    r"\.env(\..+)?",
    r".+\.pem", r".+\.key", r".+\.secret", r".+-secret",
    r"id_(rsa|dsa|ecdsa|ed25519)(\..+)?",
    r"credentials\.(json|yaml|yml)",
    r"secrets\.(json|yaml|yml)",
    r".+\.p12", r".+\.pfx", r".+\.kdbx",
    r"\.netrc", r"_netrc",
    r"\.htpasswd", r".+\.htpasswd",
]
EXCLUDE_SUFFIX = (".example", ".sample", ".template")

CONTENT_PATTERNS = {
    "aws_access_key": r"AKIA[0-9A-Z]{16}",
    "aws_secret_key": r"aws_secret_access_key\s*=\s*[\"']?[A-Za-z0-9/+=]{40}[\"']?",
    "github_pat": r"ghp_[A-Za-z0-9]{36}",
    "github_oauth": r"gho_[A-Za-z0-9]{36}",
    "slack_token": r"xox[baprs]-[0-9A-Za-z-]{10,}",
    "google_api_key": r"AIza[0-9A-Za-z\-_]{35}",
    "stripe_key": r"sk_live_[0-9a-zA-Z]{24,}",
    "anthropic_key": r"sk-ant-[A-Za-z0-9\-_]{20,}",
    "openai_key": r"sk-[A-Za-z0-9]{48}",
    "private_key_pem": r"-----BEGIN (RSA |EC |OPENSSH |DSA |PGP |)PRIVATE KEY-----",
    "bearer_token": r"Bearer\s+[A-Za-z0-9\-_=]{20,}",
    "generic_password": r"(?i)(password|passwd|secret|api[-_]?key)\s*[:=]\s*[\"']?[^\"'\s]{8,}[\"']?",
    "jwt": r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+",
    "azure_storage": r"DefaultEndpointsProtocol=https;AccountName=[A-Za-z0-9]+;AccountKey=[A-Za-z0-9+/=]+",
}

def is_binary(path: pathlib.Path) -> bool:
    """先頭 8KB に NUL バイトを含むファイルはバイナリ判定."""
    try:
        chunk = path.read_bytes()[:8192]
    except Exception:
        return True
    return b"\x00" in chunk

def scan(plugin_root: pathlib.Path) -> list[dict]:
    findings = []
    for path in plugin_root.rglob("*"):
        if not path.is_file():
            continue
        if path.name.endswith(EXCLUDE_SUFFIX):
            continue
        # ファイル名完全一致で照合
        for pat in FILE_PATTERNS_FULL:
            if re.fullmatch(pat, path.name):
                findings.append({"file": str(path), "reason": f"filename:{pat}"})
                break
        # バイナリは内容スキャン対象外
        if is_binary(path):
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="strict")
        except UnicodeDecodeError:
            # UTF-8 でデコード不能なら CP932 / UTF-16 を試行
            for enc in ("cp932", "utf-16"):
                try:
                    text = path.read_text(encoding=enc, errors="strict")
                    break
                except UnicodeDecodeError:
                    continue
            else:
                continue
        except Exception:
            continue
        for name, pat in CONTENT_PATTERNS.items():
            if re.search(pat, text):
                findings.append({"file": str(path), "reason": f"content:{name}"})
    return findings
```

実装ヒント:
- ファイル名は `re.fullmatch` で完全一致を要求（先頭一致による誤検出を排除）
- `errors="strict"` + 例外時に他エンコーディングを試行することで、無効バイト破棄による検出漏れを防ぐ
- バイナリファイルは `\x00` 検出でスキップ（読み込みコスト削減）

## 5. 関連ルール

- 検出されたシークレットが既にコミット履歴にある場合、本スキルでは履歴の書き換えを行わない（`git filter-repo` 等は別途ユーザに案内）
- 認証情報そのものの管理はグローバル `credentials-manager` スキルに委譲。本スキルは公開対象に「混入していないか」のみを担当する
- 関連: [`../../../references/validation-rules.md`](../../../references/validation-rules.md) のセクション 2.2「プラグイン実体検証」
