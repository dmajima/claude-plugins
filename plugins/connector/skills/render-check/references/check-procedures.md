# チェック手順詳細（render-check）

`render-check` スキルの 5 カテゴリ検査の具体手順。検出パターンの定義はターゲット別レンダリングルール（プラグイン共通 `references/rendering/`）を参照し、本ファイルは **適用方法** を定める。

> 本ファイルは `skills/render-check/references/` に配置されているため、プラグイン共通 references への相対参照は `../../../references/` で始まる（SKILL.md からは `../../references/`）。

## 0. 前処理: コードフェンス内外の分割

AUTOLINK / NOTATION 検査の誤検出を防ぐため、本文を **コード領域** と **地の文** に分割してから検査する。

| ターゲット | コード領域の境界 |
|-----------|----------------|
| `backlog-notation` | `{code}` 〜 `{/code}` |
| `backlog-markdown` / `ado-markdown` | バッククォート 3 つのフェンス行ペア + インラインコード（バッククォート 1 つ） |
| `ado-workitem-html` | `<pre>` 〜 `</pre>` |

- フェンス行が **奇数個** の場合は分割不能 → STRUCTURE の FAIL として先に報告する（未クローズフェンス）
- 自動リンク・メンション検査（カテゴリ 2）は **地の文のみ** を対象とする
- 記法混入検査（カテゴリ 1）はコード領域内の構文を無視する（コード例として記載されたものは混入ではない）

## 1. NOTATION（記法整合）

1. ターゲットに対応するレンダリングルールの「混入検出パターン」表を地の文に適用する
   - `backlog-notation` → [backlog-notation.md](../../../references/rendering/backlog-notation.md) セクション 3
   - `backlog-markdown` → [backlog-markdown.md](../../../references/rendering/backlog-markdown.md) セクション 3
   - `ado-markdown` / `ado-workitem-html` → [azure-devops-markdown.md](../../../references/rendering/azure-devops-markdown.md) セクション 4
2. 検出した行番号・該当構文・表示のされ方（「そのまま文字として表示される」等）を記録する
3. 各ルールの判定列（FAIL / WARN）をそのまま採用する

## 2. AUTOLINK（自動リンク・メンション）

1. 地の文に対しターゲットのレンダリングルールの「自動リンク・通知」表を適用する
2. 検出時は以下を区別して報告する:
   - **通知が発生するもの**（`@` メンション）: 通知先（と思われる文字列）を明示し WARN
   - **リンク化のみ**（課題キー・`#` / `!` + 数字）: 意図的なリンクの可能性があるため WARN とし、「意図したリンクか」をユーザーに確認
3. コード・ログの引用が地の文に裸で置かれている場合（フェンス保護なし）は、フェンスで囲む修正案を優先して提示する

## 3. STRUCTURE（構造崩れ）

| 検査 | 方法 | 判定 |
|-----|------|------|
| コードフェンス開閉 | フェンス境界（前処理 0）が偶数ペアで閉じているか | 未クローズ = FAIL |
| 表の列数 | 同一の表ブロック内で `\|` 区切りの列数が全行一致するか | 不一致 = FAIL |
| Markdown 表の区切り行 | ヘッダ直下に `\|---\|` 行があるか（`backlog-markdown` / `ado-markdown` のみ） | 欠落 = WARN（表として描画されない） |
| Backlog 表のヘッダ指定 | ヘッダ行末尾の `h`（`backlog-notation` のみ） | 欠落 = WARN |
| リストネスト | インデント幅の不整合（Markdown 系のみ） | 不整合 = WARN |
| HTML タグ開閉 | `ado-workitem-html` のみ。`<b>` `<pre>` `<ul>` 等の開閉対応 | 未クローズ = FAIL |

## 4. SECRET（機密情報）

本文全体（コード領域含む）に以下を適用する。

> **本パターン表は網羅ではなく既知形式のベストエフォート**。PASS / WARN でも、利用者が貼り付けたログ・差分には未知形式のシークレットが残存しうる。プレビュー承認時にユーザー自身の目視確認を促す一文を添えること。

### 確定的パターン（FAIL — 投稿ブロック・マスク必須）

| パターン | 種別 |
|---------|------|
| `sk-[A-Za-z0-9_-]{16,}` | OpenAI API Key |
| `gh[pousr]_[A-Za-z0-9]{20,}` | GitHub Token（classic） |
| `github_pat_[A-Za-z0-9_]{22,}` | GitHub Fine-grained PAT |
| `xox[bpars]-[A-Za-z0-9-]{10,}` / `xapp-[0-9]-[A-Za-z0-9-]{10,}` | Slack Token / App Token |
| `AKIA[0-9A-Z]{16}` | AWS Access Key ID |
| `AIza[0-9A-Za-z_-]{35}` | Google API Key |
| `glpat-[A-Za-z0-9_-]{20,}` | GitLab PAT |
| `npm_[A-Za-z0-9]{36}` | npm Token |
| `eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{5,}` | JWT |
| `Bearer\s+[A-Za-z0-9._~+/=-]{16,}` | Bearer Token |
| `Basic\s+[A-Za-z0-9+/=]{16,}` | Basic 認証ヘッダ |
| `-----BEGIN [A-Z ]*PRIVATE KEY-----` | PEM 秘密鍵 |
| `apiKey=[^&\s"']{16,}` | API キー付き URL |
| `://[^/\s:@]+:[^/\s:@]+@` | URL 埋め込み資格情報（`scheme://user:pass@host`） |

### ヒューリスティックパターン（WARN — ユーザー判断）

| パターン | 種別 |
|---------|------|
| `(?i)(password|passwd|pwd|secret|api_?key|token)\s*[=:]\s*\S{8,}` | 代入形式の機密らしき値（JSON の `"client_secret": "..."` 等を含む） |
| `(?i)(connection\s*string|data source|server)=.*(password|pwd)=` | DB 接続文字列 |
| 文脈語（pat / token / azure / secret）の近傍にある 40 文字以上の英数記号連続文字列 | Azure DevOps PAT（52 文字 base32・プレフィックスなし）等の高エントロピー値 |
| 内部ホスト名・内部 IP（`10.` / `192.168.` 等）の露出 | 内部情報（投稿先が社外可視の場合に注意喚起） |

検出値は **マスクして報告**（先頭 4 文字 + `***` + 末尾 4 文字）。フル値を会話出力に転記しない。

## 5. SIZE（サイズ・文字数）

| ターゲット | 閾値 | 判定 |
|-----------|------|------|
| `backlog-*` | 8,000 文字超 | WARN（分割投稿を提案） |
| `ado-markdown`（PR 説明） | 4,000 文字超 | WARN（超過分が切り捨てられる旨を提示し、コメント分割を提案） |
| `ado-markdown`（コメント）/ `ado-workitem-html` | 8,000 文字超 | WARN |

## 6. 結果の組み立て

1. 検出項目を「カテゴリ / 判定 / 内容 / 位置（行番号）」の表に整理する
2. 総合判定: FAIL が 1 件でもあれば FAIL、FAIL なし・WARN ありは WARN、いずれもなければ PASS
3. プレビュー: 本文をコードブロックで提示し、リンク化・通知・装飾の発生箇所を注記する
4. FAIL / WARN には各レンダリングルールの「修正提案の変換表」に基づく修正済み本文を添える
5. 修正を採用した場合は修正後本文で **全カテゴリを再チェック** する（部分再検査をしない）
