# PR 識別子のバリデーション・TFS ホスト登録（SSOT）

`pr-review` スキル Step 1（ホスト判定）の前段で、ユーザーから受領した PR 識別子（URL / ID）をホワイトリスト正規表現で検証し、TFS Server の場合はホスト名を解決する手順。

> **位置付け**: `pr-review/SKILL.md` Step 1〜1.1 から分離した SSOT。コマンドインジェクション対策・SSRF 対策の中核として `gh` / `az` / `git` / `curl` の引数に渡す前に必ず通過させる。

---

## 1. ホワイトリスト正規表現

PR 識別子は以下の正規表現で検証してから API に渡す:

| 形式 | 正規表現 |
|------|---------|
| ID 単体 | `^#?[0-9]{1,10}$` |
| GitHub URL | `^https://(www\.)?github\.com/[A-Za-z0-9](?:[A-Za-z0-9_.-]{0,38}[A-Za-z0-9])?/[A-Za-z0-9_.-]{1,100}/pull/[0-9]{1,10}$` |
| Azure DevOps URL（クラウド） | `^https://dev\.azure\.com/[A-Za-z0-9](?:[A-Za-z0-9-]{0,48}[A-Za-z0-9])?/[A-Za-z0-9_.-]{1,64}/_git/[A-Za-z0-9_.-]{1,64}/pullrequest/[0-9]{1,10}$` |
| Azure DevOps URL（旧 visualstudio.com） | `^https://[A-Za-z0-9-]{1,50}\.visualstudio\.com/[A-Za-z0-9_.-]{1,64}/_git/[A-Za-z0-9_.-]{1,64}/pullrequest/[0-9]{1,10}$` |
| **TFS Server URL** | `^https://(?!dev\.azure\.com/)(?![A-Za-z0-9-]{1,50}\.visualstudio\.com/)[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?){1,5}/tfs/[A-Za-z0-9_.-]{1,64}/[A-Za-z0-9_.-]{1,64}/_git/[A-Za-z0-9_.-]{1,64}/pullrequest/[0-9]{1,10}$` |

## 2. 検証ルール

- **連続ドット禁止**: TFS URL ホスト部分はラベル単位（先頭・末尾英数字）に分解し、`..` を構造的に拒否
- **クラウド排他**: TFS URL 正規表現の先頭に negative lookahead を入れて、クラウド URL が TFS 経路（NTLM 認証）に誤って分岐するのを防ぐ
- **ASCII 限定**: 全セグメントで Unicode 文字を排除（ホモグラフ攻撃対策）
- **長さ上限**: ホスト各ラベル 63 文字、PR ID 10 桁、セグメント 64〜100 文字

検証に失敗した識別子は **拒否してユーザーに正しい形式を案内** する。直接 `gh` / `az` / `git` / `curl` の引数として渡してはならない。

加えて、ホスト判定後は抽出した host が **TFS ホスト登録値（後述）と完全一致** することを最終検証する（URL ホスト名の二重チェック）。

## 3. TFS Server ホストの登録方法

ID 単体（`#45`）で渡された場合、TFS Server かどうかを判定するために TFS ホスト名を事前に登録する必要がある。以下の優先順位で解決する:

| 優先 | 取得元 | 例 |
|------|--------|------|
| 1 | スキル引数 `host=<tfs-host>` を明示 | `Skill(skill: "pr-review", args: "#45 host=tfs.example.com")` |
| 2 | レビュー対象リポジトリの `CLAUDE.md` 内で `tfs_host: <hostname>` 行を定義 | `tfs_host: tfs.example.com` |
| 3 | connector 経由で credentials-manager ストアの `tfs-password` エントリの `urls[0]` から抽出（ストア: `.claude/.local/plugins/credentials-manager/credentials.json`。connector が解決） | `urls: ["https://tfs.example.com/*"]` → `tfs.example.com` |
| 4 | カレントディレクトリの `git remote -v` 出力から抽出 | `origin https://tfs.example.com/tfs/...` |

いずれも見つからない場合はユーザーに「TFS ホスト名を教えてください」と確認する。**フォールバック値（既定値）は持たない**（特定組織固有の値などをハードコードしない）。

## 4. TFS / Cloud 判別（Step 1.1）

TFS / Cloud 判別は **connector:azure の host-detection.md**（credentials.json の `tfs-password.domains` 照合）に委譲する。pr-review から HTTP HEAD プローブは行わない。

- URL ホストが `dev.azure.com` / `*.visualstudio.com` → **クラウド Azure DevOps**
- URL ホストが credentials.json の `tfs-password.domains` に登録済み → **TFS Server**
- いずれにも該当しない → ユーザーに確認

## 5. 関連リファレンス

- `${CLAUDE_SKILL_DIR}/SKILL.md` Step 1 — 本ファイルの呼び出し元
- `${CLAUDE_SKILL_DIR}/references/azure-devops-tfs-ntlm.md` — NTLM 認証時の host ホワイトリスト二重チェック
