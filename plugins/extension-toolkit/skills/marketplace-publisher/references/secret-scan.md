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
| Stripe Restricted Key | `rk_(live\|test)_[0-9a-zA-Z]{24,}` |
| Anthropic API Key | `sk-ant-(api\d+-)?[A-Za-z0-9\-_]{20,}` |
| OpenAI API Key（legacy） | `sk-(?!proj-)(?!svcacct-)(?!ant-)[A-Za-z0-9]{48}` |
| OpenAI Project Key | `sk-proj-[A-Za-z0-9_-]{20,}` |
| OpenAI Service Account Key | `sk-svcacct-[A-Za-z0-9_-]{20,}` |
| GCP Private Key ID | `"private_key_id"\s*:\s*"[a-f0-9]{40}"` |
| 秘密鍵（PEM ヘッダー） | `-----BEGIN (RSA \|EC \|OPENSSH \|DSA \|PGP \|)PRIVATE KEY-----` |
| Generic Bearer Token | `Bearer\s+[A-Za-z0-9\-_=]{20,}` |
| Generic Password 代入（クォート任意、16+ 高エントロピー要件）| `(?i)(password\|passwd\|secret\|api[-_]?key)\s*[:=]\s*["']?[A-Za-z0-9+/=_\-\.]{16,}["']?` |
| JWT | `eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+` |
| Azure Storage Key | `DefaultEndpointsProtocol=https;AccountName=[A-Za-z0-9]+;AccountKey=[A-Za-z0-9+/=]+` |
| Azure SAS Token | `sig=[A-Za-z0-9%]{20,}(&\|$)` |

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

### 非対話・フルオート併用時の特例（fail-closed 強化）

`--non-interactive` または `--full-auto` で対話確認が成立しない環境では、選択肢 3「誤検出として続行」を **提供しない**。検出時は常に exit 1（公開中断）とし、利用者が対話モードで再実行するか、選択肢 1（削除）/ 選択肢 2（gitignore 追加）の事前準備を行ってから再実行する必要がある。

| モード | 選択肢 1（削除） | 選択肢 2（gitignore） | 選択肢 3（続行） | 選択肢 4（キャンセル） |
|-------|-----------------|--------------------|----------------|--------------------|
| 対話モード | 提供 | 提供 | 提供（二重確認） | 提供 |
| 非対話 + フルオート | 案内のみ（再実行待ち） | 案内のみ（再実行待ち） | **不可（fail-closed）** | 案内のみ |

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
    "github_user_server": r"ghu_[A-Za-z0-9]{36}",
    "github_server_server": r"ghs_[A-Za-z0-9]{36}",
    "github_refresh": r"ghr_[A-Za-z0-9]{36}",
    "slack_token": r"xox[baprs]-[0-9A-Za-z-]{10,}",
    "google_api_key": r"AIza[0-9A-Za-z\-_]{35}",
    "stripe_key": r"sk_live_[0-9a-zA-Z]{24,}",
    "stripe_restricted_key": r"rk_(live|test)_[0-9a-zA-Z]{24,}",
    "anthropic_key": r"sk-ant-(api\d+-)?[A-Za-z0-9\-_]{20,}",
    "openai_key": r"sk-(?!proj-)(?!svcacct-)(?!ant-)[A-Za-z0-9]{48}",
    "openai_proj_key": r"sk-proj-[A-Za-z0-9_-]{20,}",
    "openai_svcacct_key": r"sk-svcacct-[A-Za-z0-9_-]{20,}",
    "private_key_pem": r"-----BEGIN (RSA |EC |OPENSSH |DSA |PGP |)PRIVATE KEY-----",
    "bearer_token": r"Bearer\s+[A-Za-z0-9\-_=]{20,}",
    # Generic Password: 値長 16+ かつ高エントロピー要件あり（短いプレースホルダ・examplevalue 等の誤検出を抑制）
    "generic_password": r"(?i)(password|passwd|secret|api[-_]?key)\s*[:=]\s*[\"']?[A-Za-z0-9+/=_\-\.]{16,}[\"']?",
    "jwt": r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+",
    "azure_storage": r"DefaultEndpointsProtocol=https;AccountName=[A-Za-z0-9]+;AccountKey=[A-Za-z0-9+/=]+",
    "azure_sas_token": r"sig=[A-Za-z0-9%]{20,}(?:&|$)",
    "gcp_private_key_id": r'"private_key_id"\s*:\s*"[a-f0-9]{40}"',
}

# プレースホルダ（テンプレート値）の除外パターン
PLACEHOLDER_PATTERNS = [
    r"\$\{[A-Z_]+\}",        # ${ENV_VAR}
    r"\{\{[a-z_]+\}\}",      # {{template}}
    r"<[a-z-]+>",            # <placeholder>
    r"\$\([A-Z_]+\)",        # $(VAR)
]

# スキャン対象から除外するディレクトリ
EXCLUDE_DIRS = {".git", ".venv", "node_modules", "__pycache__", ".tox", ".mypy_cache"}

def is_binary(path: pathlib.Path) -> bool:
    """先頭 8KB に NUL バイトを含むファイルはバイナリ判定（BOM 持ちは除外）."""
    try:
        chunk = path.read_bytes()[:8192]
    except Exception:
        return True
    # UTF-16 / UTF-8 BOM を持つファイルはテキストとして扱う
    if chunk.startswith(b"\xff\xfe") or chunk.startswith(b"\xfe\xff") or chunk.startswith(b"\xef\xbb\xbf"):
        return False
    return b"\x00" in chunk

def is_in_excluded_dir(path: pathlib.Path, root: pathlib.Path) -> bool:
    """パスのいずれかの親が EXCLUDE_DIRS に該当するか判定."""
    rel = path.relative_to(root)
    return any(part in EXCLUDE_DIRS for part in rel.parts)

def is_placeholder_value(value: str) -> bool:
    """値がテンプレートプレースホルダか判定."""
    return any(re.search(pat, value) for pat in PLACEHOLDER_PATTERNS)

def scan(plugin_root: pathlib.Path) -> list[dict]:
    findings = []
    for path in plugin_root.rglob("*"):
        if not path.is_file():
            continue
        # 除外ディレクトリ配下はスキップ（.git / .venv / node_modules 等）
        if is_in_excluded_dir(path, plugin_root):
            continue
        # ファイル名照合（テンプレート系サフィックスは除外）
        # ただし内容スキャンは常に実施する（テンプレートと称した実値含有の検出のため）
        if not path.name.endswith(EXCLUDE_SUFFIX):
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
            for m in re.finditer(pat, text):
                # プレースホルダ値は除外
                matched = m.group(0)
                if is_placeholder_value(matched):
                    continue
                # 行番号を計算（マッチ位置までの改行数 + 1）
                line_num = text[: m.start()].count("\n") + 1
                # CWE-532 対応: 検出値の prefix も残さない（パターン名 + ファイルパス + 行番号のみ）
                findings.append({"file": str(path), "line": line_num, "reason": f"content:{name}"})
                break
    return findings
```

実装ヒント:
- ファイル名は `re.fullmatch` で完全一致を要求（先頭一致による誤検出を排除）
- `EXCLUDE_SUFFIX` はファイル名照合のみに適用し、**内容スキャンは常に実施**（テンプレート名で偽装されたシークレットを検出）
- `EXCLUDE_DIRS`（`.git/` `.venv/` `node_modules/` 等）配下は走査しない（無駄なコスト + 偽陽性削減）
- `errors="strict"` + 例外時に他エンコーディングを試行することで、無効バイト破棄による検出漏れを防ぐ
- バイナリファイルは `\x00` 検出でスキップ（読み込みコスト削減）。BOM（`\xef\xbb\xbf` UTF-8 / `\xff\xfe` UTF-16 LE / `\xfe\xff` UTF-16 BE）を持つ場合は対応エンコーディングで再評価する
- プレースホルダ値（`${VAR}` / `{{template}}` / `<placeholder>` / `$(VAR)`）は誤検出抑制のため除外
- 検出ログには **検出パターン名 + ファイルパス + 行番号** のみ記録する。値の prefix も残さない（CWE-532 情報露出防止）。値を確認したい場合は対話モードでユーザに直接ファイルを開かせる
- ドキュメントファイル（`*.md` / `*.rst`）でかつコードフェンス（` ``` ` 区切り）の **外側** にあるパターンは Generic Password の検出から除外することを推奨（例: `password: hunter2` を解説する文書を誤検出しない）。実装は `re.finditer` で行ごとにコードフェンス境界を追跡する

## 5. 関連ルール

- 検出されたシークレットが既にコミット履歴にある場合、本スキルでは履歴の書き換えを行わない（`git filter-repo` 等は別途ユーザに案内）
- 認証情報そのものの管理はグローバル `credentials-manager` スキル（インストール済みの場合）に委譲。本スキルは公開対象に「混入していないか」のみを担当する。`credentials-manager` 未導入時は利用者に直接認証情報の確認・再設定を依頼する（ADR-022 自己完結性原則のグローバルスキル依存フォールバック）
- 関連: [`../../../references/validation-rules.md`](../../../references/validation-rules.md) のセクション 2.2「プラグイン実体検証」
