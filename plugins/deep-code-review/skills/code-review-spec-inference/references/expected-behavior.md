# 期待挙動の推論（仕様書代替・補完）

`pr-review` スキルが **仕様書（`spec=<path>`）が引数で渡されていない場合**、または渡されていても情報が不足している場合に、PR 内の自然言語情報・既存コメント・外部リンク先資料から「あるべき姿」を推論するためのロジック・基準を定義する。

> **目的**: 仕様書が存在しない PR でも、PR 説明文・過去コメント・外部資料リンク（Backlog、TFS Boards、社内 Wiki 等）から要件を再構築し、code-review の判定根拠とする。

---

## 0. 安全方針（必須・最優先）

外部リンクの自動 fetch における SSRF / 認証情報誤送信対策は、**プラグイン共通リファレンス `${CLAUDE_PLUGIN_ROOT}/references/safe-external-fetch.md` に集約済み** です。本スキルは同ファイルの規定（ドメインホワイトリスト・内部 IP 拒否・タイムアウト/サイズ制限・リダイレクト再検証・サニタイズ・禁止事項）を **そのまま準拠** します。

### 0.1 fetch 承認の責務分担（dry-run）

外部 fetch の **候補提示とユーザー承認（dry-run）は呼び出し元 `pr-review` の責務** である（`pr-review` が `AskUserQuestion` で承認を得る）。本スキル（spec-inference）は **委譲起動のみで対話 UI（AskUserQuestion）を持たない** ため、承認済みの fetch ポリシーを受け取って動作する:

- **`fetch-external=ask`（既定）**: `pr-review` が外部 fetch 前に「fetch 候補の一覧」をユーザーに提示し承認を得る。承認後、`pr-review` は `fetch-external=auto` 相当で spec-inference に委譲する
- **`fetch-external=auto`**: 承認済みとして spec-inference が候補を fetch する（本スキルは追加の確認をしない）
- **`fetch-external=off`**: 外部 fetch を行わない

#### dry-run 提示例（提示するのは `pr-review`）

```
## 外部資料の参照候補

PR description / コメントから以下のリンクを検出しました:

1. https://example.backlog.jp/view/PROJECT-123 — Backlog 課題（credentials 登録あり: backlog-api-key）
2. https://tfs.example.com/tfs/.../_workitems/edit/4567 — TFS Work Item（credentials 登録あり: tfs-password）
3. https://internal-wiki.example.com/spec.html — 社内 Wiki（credentials 登録なし → スキップ）

これらを取得して期待挙動の推論に利用しますか？
```

`pr-review` がユーザー承認を得た後、spec-inference へ委譲して fetch を実行する。

---

## 1. 入力の優先順位

期待挙動を構築する情報源の **信頼度・優先順位**:

| 優先 | 情報源 | 重み |
|------|--------|------|
| 1 | `spec=<path>` で明示された仕様書 | 最高（決定的根拠） |
| 2 | PR description（タイトル直下の本文） | 高 |
| 3 | description 内の **外部リンク先資料**（Backlog 課題、TFS Work Item 等） | 高 |
| 4 | description 内の **資料パス**（リポジトリ内 `docs/spec.md` 等） | 高 |
| 5 | PR の過去コメント（人間レビュアーの指摘・要望） | 中 |
| 6 | PR の過去コメント（Bot/自身の前回レビュー） | 中（合意済み方針として扱う） |
| 7 | コミットメッセージ | 低（補助情報） |

複数情報源で矛盾がある場合は **優先度の高い情報源** を採用し、矛盾点を完了報告に明示する。

---

## 2. PR description の解析

### 2.1 構造化された見出しの抽出

description 内の以下の見出し直下の本文を「期待挙動」として優先度高く扱う:

| 見出しパターン | 抽出する内容 |
|--------------|------------|
| `## 概要` / `## Summary` / `## Overview` | 機能の概要 |
| `## 要件` / `## Requirements` | 必須要件 |
| `## 期待挙動` / `## Expected Behavior` / `## 仕様` | 期待される動作 |
| `## 受入条件` / `## Acceptance Criteria` / `## DoD` | 完了条件 |
| `## テスト計画` / `## Test Plan` | テストすべき経路 |
| `## 関連課題` / `## Related Issues` / `## 参考` / `## References` | 外部リンクが記載されることが多い |

### 2.2 自由記述の解析

見出しがない場合は description 全体を自然言語として解析。「変更点」「目的」「Why」を抽出。

### 2.3 チェックリストの扱い

`- [ ]` 形式のタスクリストは「実施予定の項目」または「完了基準」として扱う。**未チェック項目は修正未完了の可能性**があるため再レビュー時にコード差分と照合する。

---

## 3. 外部リンクの抽出と fetch

### 3.1 抽出対象パターン

description / コメント本文から以下を正規表現で抽出する（**ASCII URL のみ**、Unicode ホモグラフ攻撃対策）:

| 種類 | パターン例 | 取得方法 |
|------|----------|---------|
| Backlog 課題 | `https://[A-Za-z0-9-]+\.backlog\.(jp\|com)/view/[A-Z]+-[0-9]+` | Backlog API |
| Backlog Wiki | `https://[A-Za-z0-9-]+\.backlog\.(jp\|com)/wiki/[A-Z]+/[A-Za-z0-9_/-]+` | Backlog API |
| TFS Work Item | `https://[A-Za-z0-9.-]+/tfs/[A-Za-z0-9_-]+/[A-Za-z0-9_-]+/_workitems/edit/[0-9]+` | NTLM REST API |
| Azure Boards (Cloud) | `https://dev\.azure\.com/[A-Za-z0-9-]+/[A-Za-z0-9_-]+/_workitems/edit/[0-9]+` | `az boards work-item show` |
| 社内 Wiki | `https://wiki[.][A-Za-z0-9.-]+/[A-Za-z0-9_/-]+` | Basic 認証 / Cookie 認証 |
| GitHub Issue | `https://github\.com/[A-Za-z0-9_-]+/[A-Za-z0-9._-]+/issues/[0-9]+` | `gh issue view` |
| 一般 HTTPS URL | `https://[^\s\]\)>"]+` | フォールバック（要ホワイトリスト） |
| リポジトリ内パス | `[A-Za-z0-9_/-]+\.(md\|txt\|adoc)` | Read ツールで直接読み込み |

抽出後、各 URL を **セクション 0.1 のホワイトリストチェック** に通す。一致しないものは fetch しない。

### 3.2 取得方法のディスパッチ

ホワイトリスト照合を通過した URL は、**認証の要否** で取得経路を分ける（SSRF 経路を最小化するため raw `curl` は使わない）:

| 種別 | 取得経路 |
|------|---------|
| **認証不要の公開資料** | ガードスクリプト `${CLAUDE_PLUGIN_ROOT}/references/scripts/fetch/safe_fetch.sh <url> <allowed_hosts_csv>` 経由（ホワイトリスト・内部 IP 拒否・IP ピン留め・上限をツール層で強制） |
| **認証が必要な資料**（Backlog / TFS Boards / Azure Boards / GitHub Issues 等） | 対応する **connector スキルに委譲**（`connector:backlog-read` / `connector:azure-read-pr` 系 / `connector:github-read` 等）。認証情報の付与・API 呼び出しは connector 側の責務。spec-inference は取得を依頼し結果を受け取るのみ |

`credentials.json` のエントリで `domains[]` / `urls[]` が一致し `auth_method` が定義されている場合は、対応する connector スキルに委譲する（spec-inference 自身は認証ヘッダ付き raw `curl` を実行しない。認証情報の値をコマンドライン・ログに載せる経路を排除するため）。connector が未対応の認証方式（`form:` / `custom:`）はサポート対象外とし、手動で資料を提供するよう求める。

### 3.3 取得した内容の構造化

取得した HTML / JSON / Markdown は以下に正規化する:

```
## 外部資料: <タイトル>
- URL: <URL>
- 種類: <Backlog課題 / TFS Work Item / Wiki / ...>
- 取得日時: <ISO 8601>

### 概要
<本文の要約>

### 受入条件 / 完了条件
<抽出された箇条書き>

### 関連リンク
<本文中の更なるリンク（追跡しない、参考表示のみ）>
```

### 3.4 取得失敗時の挙動

- 401/403 → 認証情報の更新を促す（ユーザーへ手動更新を依頼。**credentials-manager プラグイン経由**で対応エントリを更新してもらう。connector が解決する標準ストア `.claude/.local/plugins/credentials-manager/credentials.json` に反映される）
- 404 → 「リンク切れ」として報告。手動で資料を提供するよう求める
- タイムアウト / サイズ超過 → 部分取得分を使い、残りはユーザーに告知
- ホワイトリスト不一致 → 「URL は検出したが認証情報未登録のためスキップ」と明示

---

## 4. 過去コメントの考慮

### 4.1 人間レビュアーのコメント

- 「この機能は XX すべき」「YY を考慮して」等の **要望/制約** を抽出
- 「既存仕様では …」のような **既知仕様への言及** は仕様書代替として扱う
- スレッドが既に `resolved` / `fixed` の場合、その解消経緯も「合意済み方針」として参照

### 4.2 Bot / 自身の過去レビュー

- 過去のレビュー指摘で auto-resolve（既定）で自動解消されたものは「合意済み修正」として扱う
- Pattern C（未解消）で残っている指摘は「未対応の懸念」として現在の差分でも確認する
- Bot 識別子（`🤖 [deep-code-review-plugin]`）で自身のコメントを判別

### 4.3 コメントスレッドの時系列

複数の reply を持つスレッドでは **最新の comment を最優先** で参照（議論の収束結果が最新にあると仮定）。

---

## 5. リポジトリ内パス参照

description / コメントに `docs/spec.md` `requirements/v2.adoc` のような **リポジトリ内パス** が記載されている場合:

1. リポジトリルートからの相対パスとして解決
2. パストラバーサル検証（`..` 含む / 絶対パス / ホームディレクトリ参照は拒否）
3. ファイルが存在すれば Read ツールで直接読み込み
4. 存在しない場合は「指定された資料が見つかりません」とユーザーに通知

実装例:

```bash
# 検証
case "$path" in
  /*|*..*|~*) echo "invalid path: $path"; exit 1 ;;
esac

# リポジトリルート + 相対パスで解決
abs_path="$(git rev-parse --show-toplevel)/$path"

# 存在確認 + Read
[ -f "$abs_path" ] || { echo "not found: $path"; exit 1; }
```

---

## 6. 期待挙動サマリの構築

上記 1〜5 の情報を統合し、以下の構造で「期待挙動サマリ」を生成する:

```markdown
# 期待挙動サマリ

## ソース
- spec=<path>（あれば）: <要約>
- PR description: <要約>
- 外部資料 1: <タイトル>（<URL>）— <要約>
- 外部資料 2: ...
- 過去コメント要点: <要約>

## 抽出された要件
1. <要件1>
2. <要件2>
...

## 抽出された受入条件
1. <受入条件1>
2. <受入条件2>
...

## 矛盾 / 未確定事項
- <情報源 A は X、情報源 B は Y。優先度に従い X を採用>
- <description にあるが外部資料未取得のため未確定>
```

このサマリを **`code-review` への引数 `spec_summary=<期待挙動サマリ>` として渡す**（プロジェクト規約サマリ `project-rules-summary` とは別系統の引数。委譲引数フォーマットは `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/flow/flow.md` Step 4 を参照）。観点別レビュアーはこれを「あるべき姿」として参照し、コード差分との整合性を判定する。

---

## 7. 完了報告に含める内容

レビュー完了報告に以下を必ず明記する:

- 仕様書（`spec=<path>`）の有無
- PR description から抽出した見出し
- fetch 成功した外部資料の件数（成功/失敗内訳）
- ホワイトリスト不一致でスキップした外部 URL の件数
- 矛盾した情報源があった場合は明示

これにより、ユーザーは「どこまでの情報をもとにレビューされたか」を追跡できる。

---

## 8. 禁止事項

- ホワイトリストに登録されていないドメインへ自動 fetch すること
- 認証情報を URL クエリで送る際の URL を **そのままログに残す** こと（マスキング必須）
- 内部 IP / IMDS / プライベート IP レンジへ自動 fetch すること
- 外部資料の取得結果を **無加工で PR コメントに転載** すること（XSS / 機密情報混入リスク。サニタイズ必須）
- 取得サイズ無制限・タイムアウト無制限で fetch すること
- 取得失敗を無視して「期待挙動が不明」と報告せず、勝手に推論で埋めること（情報源と推論を分離して報告）
