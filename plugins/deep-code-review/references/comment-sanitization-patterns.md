# コメント本文のサニタイズ — サニタイズ対策・実装（セクション 1〜4）

> **親ファイル**: [`comment-sanitization.md`](comment-sanitization.md)（索引・セクションマップ・適用契約）
> **姉妹ファイル**: [`comment-sanitization-escaping.md`](comment-sanitization-escaping.md)（予約文字エスケープ・投稿前チェックリスト / セクション 5〜5.6）
>
> 本ファイルは `comment-sanitization.md` のセクション 1〜4（適用範囲・脅威モデル・必須対策・具体的なサニタイズ実装）を収録する詳細サブファイル。セクション番号は原典を保持している。

---

## 1. 適用範囲

以下の操作を行うすべてのスキルに適用:

- `pr-review` が PR にコメント・スレッドを投稿する
- 観点別レビュースキルがレビュー結果を返す（呼び出し元の `pr-review` が投稿するので最終的にここを通る）
- 外部から取得した資料（Backlog 課題本文・TFS Work Item 等）の内容を PR コメントに転載する
- 将来追加されるすべての「外部に出力される本文を生成する」スキル

---

## 2. 脅威モデル

| 脅威 | 経路 | 影響 |
|------|------|------|
| XSS | リポジトリ内のコメントやコミットメッセージに仕込まれた HTML が PR コメントに転載 | PR 閲覧者のセッション乗っ取り（GitHub/Azure DevOps 側の Markdown レンダリングに依存） |
| トラッキング画像 | `![alt](http://attacker.example/track.png)` のような外部画像参照 | PR 閲覧者の IP / UA が攻撃者ログに漏洩 |
| リンク偽装 | `[安全そうなテキスト](javascript:...)` または `[...](data:...)` | クリック誘導による不正コード実行 |
| 機密漏洩 | レビュー対象コードに含まれる Bearer / Basic / GHP / Fine-grained PAT / JWT / Azure SAS / AWS / GCP / Slack 等のトークンが PR コメントに転載 | 認証情報の意図しない公開 |

> 補足: GitHub / Azure DevOps はサーバ側で一定のサニタイズを行うが、Markdown 画像構文・トラッキング画像・機密文字列の偶発的引用はプラグイン側で **二重防御** する。

---

## 3. 必須対策

| 対策 | 内容 |
|------|------|
| コードフェンス必須 | レビュー対象コードからの引用は **必ず ` ``` ` で囲む**（生 HTML / Markdown が解釈されないように） |
| `<img>` タグ削除 | コメント本文に `<img>` HTML タグが含まれる場合は削除 |
| 外部画像 URL の Markdown 構文を削除 | `![alt](http://attacker.example/track.png)` のような外部画像参照は除去 |
| 危険スキームのリンク削除 | `javascript:` / `data:` / `vbscript:` / `file:` リンクを検出したら **リンクテキストのみ残す**（`[text]` に置換） |
| 機密文字列の伏字化 | レビュー結果に偶発的に含まれた認証関連パターンを `***` に置換 |

---

## 4. 具体的なサニタイズ実装（sed パターン）

```bash
# RAW = 元のレビュー結果テキスト、SAFE = サニタイズ後本文
SAFE=$(printf '%s' "$RAW" \
  | sed -E 's#!\[[^]]*\]\(https?://[^)]+\)##g' \
  | sed -E 's#<img[^>]*>##gi' \
  | sed -E 's#\[([^]]+)\]\((javascript|data|vbscript|file):[^)]+\)#[\1]#gi' \
  | sed -E 's#(password|token|secret|api[_-]?key|authorization)([[:space:]]*[:=][[:space:]]*)[^[:space:]"'\''<>]+#\1\2***#gi' \
  | sed -E 's#Bearer[[:space:]]+[A-Za-z0-9_+/=.-]+#Bearer ***#g' \
  | sed -E 's#Basic[[:space:]]+[A-Za-z0-9+/=]{8,}#Basic ***#g' \
  | sed -E 's#gh[opsur]_[A-Za-z0-9]{36,}#gh*_***#g' \
  | sed -E 's#github_pat_[A-Za-z0-9_]{73,}#github_pat_***#g' \
  | sed -E 's#eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}#<JWT-token-redacted>#g' \
  | sed -E 's#AKIA[0-9A-Z]{16}#AKIA***#g' \
  | sed -E 's#AIza[0-9A-Za-z_-]{35}#AIza***#g' \
  | sed -E 's#xox[baprs]-[0-9A-Za-z-]{10,}#xox*-***#g' \
  | sed -E 's#-----BEGIN [A-Z ]*PRIVATE KEY-----#<private-key-redacted>#g' \
  | sed -E 's#(AccountKey|SharedAccessKey)=[^;"'\''[:space:]]+#\1=***#g' \
  | sed -E 's#([?&](sig|se|sp|st)=)[^&[:space:]"'\'']+#\1***#g')
```

各パターンの意味:

| パターン | 検出対象 | 置換 |
|---------|---------|------|
| `!\[[^]]*\]\(https?://[^)]+\)` | Markdown 外部画像（トラッキング） | 削除 |
| `<img[^>]*>` | HTML img タグ | 削除 |
| `\[([^]]+)\]\((javascript\|data\|vbscript\|file):[^)]+\)` | 危険スキームリンク | リンクテキストのみ残す |
| `(password\|token\|secret\|...)([:=])\S+` | キー=値 形式の認証情報 | `***` 化 |
| `Bearer\s+...` | OAuth Bearer Token | `Bearer ***` |
| `Basic\s+...` | Basic 認証ヘッダ | `Basic ***` |
| `gh[opsur]_[A-Za-z0-9]{36,}` | GitHub PAT（classic） | `gh*_***` |
| `github_pat_[A-Za-z0-9_]{73,}` | GitHub Fine-grained PAT | `github_pat_***` |
| `eyJ...\.eyJ...\.eyJ...` | JWT Token | `<JWT-token-redacted>` |
| `AKIA[0-9A-Z]{16}` | AWS アクセスキー ID | `AKIA***` |
| `AIza[0-9A-Za-z_-]{35}` | GCP API キー | `AIza***` |
| `xox[baprs]-[0-9A-Za-z-]{10,}` | Slack トークン | `xox*-***` |
| `-----BEGIN [A-Z ]*PRIVATE KEY-----` | PEM 秘密鍵ヘッダ（RSA / EC / OPENSSH 等） | `<private-key-redacted>` |
| `(AccountKey\|SharedAccessKey)=...` | Azure 接続文字列のキー | `\1=***` |
| `[?&](sig\|se\|sp\|st)=...` | Azure SAS トークンのクエリパラメータ | `\1***` |

**疑わしい場合は伏字側に倒す** 原則（false positive を許容）。
なお本パターンは **オープンセット** であり、脅威モデル（セクション 2）で列挙した機密経路のうち未カバーのものを検出した場合は本セクションに追記する（現状、脅威モデルの列挙項目はすべて本表でカバー済み）。最終的なコメント本文を確定してから `jq --arg body "$SAFE"`（または `--rawfile`）で JSON に組み込み、API に渡す。
