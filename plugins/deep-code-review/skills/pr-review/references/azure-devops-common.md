# Azure DevOps PR 操作 — 共通仕様（クラウド・オンプレ TFS の両方に適用）

> **本ファイルは connector:azure の内部実装リファレンス（デバッグ・トラブルシューティング用）として維持する。pr-review からの直接 API / CLI 実行は廃止され、すべて `connector:azure` 経由で操作する。認証情報取得も connector に委譲する（U12）。**

`pr-review` スキルが Azure DevOps Git の PR を扱う際の **クラウド・オンプレ TFS 共通仕様** をまとめたファイル。

> **位置付け**: 旧 `azure-devops.md` の 3.x 〜 6.x セクションから分離。クラウド固有の操作は `azure-devops-cloud.md`、オンプレ TFS 固有の操作は `azure-devops-tfs-ntlm.md` を参照。

---

## 1. ホスト種別と認証方式の対応表（最重要）

Azure DevOps には **2系統** あり、それぞれ利用できる認証方式・ツールが異なる。

| ホスト種別 | 例 | サポートツール | 推奨認証方式 | 補助認証 | 詳細 |
|----------|------|--------------|------------|----------|-----|
| **クラウド Azure DevOps** | `dev.azure.com` / `*.visualstudio.com` | `az devops invoke` / `az rest` / `curl` | **MS アカウント（`az login`）** | PAT（CI/CD 用） | `azure-devops-cloud.md` |
| **オンプレ TFS Server** | `tfs.<company>.com` 等 | **`curl --ntlm` のみ**（az devops 拡張は **非対応**） | **NTLM 認証（既存ドメインアカウント）** | PAT | `azure-devops-tfs-ntlm.md` |

### 重要な制約

`az devops` 拡張は実行時に以下の警告を出す:
```
WARNING: The Azure DevOps Extension for the Azure CLI does not support Azure DevOps Server.
```

そのため **オンプレ TFS では `az devops invoke` / `az repos pr` 等の az コマンドは使用不可**。REST API を `curl --ntlm` で直接呼ぶ必要がある。

---

## 2. スレッドのステータス値（共通）

| status | 意味 | 分類 |
|--------|------|------|
| `active` | 対応中 | 未解決 |
| `pending` | 保留 | 未解決 |
| `fixed` | 解消済み | 解消 |
| `wontFix` | 対応しない | 保留扱い |
| `closed` | クローズ済み | 解消 |
| `byDesign` | 仕様通り | 解消 |
| `unknown` | 不明 | 未解決扱い |

未解決判定: `active` / `pending` / `unknown`
解消判定: `fixed` / `closed` / `byDesign`
保留判定: `wontFix`（解消ではない）

---

## 3. `commentType` / `filePath` 規約（共通）

| commentType 値 | 用途 |
|----|------|
| `1`（または `"text"`） | 通常のコメント（推奨） |
| `2`（または `"codeChange"`） | コード変更に対するコメント |

`filePath`: 先頭に `/` 必須、区切り文字は `/`（Windows でも）。リポジトリルートからの絶対パス。

---

## 4. URL 解析（共通）

PR URL のパターン:

| 形式 | 例 | 認証経路 |
|------|------|---------|
| クラウド dev.azure.com | `https://dev.azure.com/<org>/<project>/_git/<repo>/pullrequest/<id>` | `azure-devops-cloud.md` |
| クラウド visualstudio.com（旧） | `https://<org>.visualstudio.com/<project>/_git/<repo>/pullrequest/<id>` | `azure-devops-cloud.md` |
| **オンプレ TFS Server** | `https://tfs.example.com/tfs/<collection>/<project>/_git/<repo>/pullrequest/<id>` | `azure-devops-tfs-ntlm.md` |

これらから `org-url` / `collection`（オンプレのみ）/ `project` / `repo` / `id` を抽出する。

PR 識別子のホワイトリスト正規表現は `pr-review/SKILL.md` 参照。

---

## 5. レート制限・パフォーマンス（共通）

- Azure DevOps REST API は概ね **200 req / minute**
- 大量コメント追加時は順次実行＋短時間スリープを挟むことを検討
- スレッド取得は1回ですべて取得できる（1 PR あたり通常 100 件以下）

429 Too Many Requests を受けた場合のリトライポリシーは `${CLAUDE_PLUGIN_ROOT}/references/http-error-handling.md` セクション 3 参照（指数バックオフ 1s/2s/4s、最大 3 回）。

---

## 6. GitHub との差分（実装上の注意）

| 項目 | GitHub | Azure DevOps |
|------|--------|-------------|
| コメント単位 | review thread | thread |
| 解消ステータス | `isResolved: true/false` | `status: active/fixed/closed/byDesign/...` |
| 範囲指定 | `start_line` + `line` + `side` | `rightFileStart` + `rightFileEnd` (line+offset) |
| 認証（クラウド） | gh CLI / `GITHUB_TOKEN` | az CLI（MS アカウント）/ PAT |
| 認証（オンプレ） | — | **NTLM（既存ドメインアカウント）** |
| パスの先頭 | リポルートからの相対 | 先頭に `/` 必須 |
| diff 取得 | `gh pr diff` 一発 | `git diff` または iterations API |

`pr-review` スキルはこの差分を吸収して統一インターフェースを提供する。

---

## 関連リファレンス

- `azure-devops-tfs-ntlm.md` — オンプレ TFS Server 専用（NTLM）
- `azure-devops-cloud.md` — クラウド Azure DevOps 専用（MS アカウント / az）
- `github.md` — GitHub PR 操作の詳細
- `author-identity.md` — 自著判定（共通実装の詳細）
