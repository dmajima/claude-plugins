# 再レビュー時の動作（既存スレッド起点フロー）

`pr-review` スキルが **修正後の再レビュー** で既存自著スレッドを起点に動作するための **4 パターン分岐 + reply テンプレート + 対象抽出条件 + API 呼び出し** をまとめたファイル。

> **位置付け**: 旧 `comment-status.md` から分離（403 行 → 3 ファイルへの構造リファクタリング）。本ファイルは「再レビュー実行時の動作仕様」に特化。

---

## 1. 動作原則

修正後の再レビューでは **新規スレッド作成前に、まず既存の自著スレッドを起点に動作する** こと。

| 状態 | 動作 |
|------|------|
| 既存スレッドの指摘が **解消されている** | 該当スレッドの **status を `fixed` / `resolved` に更新** + 同スレッドへの **解消確認 reply** を投稿（Pattern A。`auto-resolve=false` 指定時を除き status 更新まで実施） |
| 既存スレッドの指摘が **解消されていない** | スレッドの status は **active のまま維持** + 同スレッドへの **再観察 reply** を投稿（新規スレッドは作らない）（Pattern C） |
| **ユーザーが「スコープ外として了承」と Finding ID 指定で指示** | 該当スレッドに **了承 reply** を投稿 + status を `wontFix` / `resolved` に更新（Pattern D） |
| **ユーザーが修正指示 + Claude が修正コミットを作成済み** | 該当スレッドに **修正完了 reply**（修正コミットへの明示リンク必須）を投稿 + status を `fixed` / `resolved` に更新（Pattern E） |
| **新規発見の指摘** | 新スレッドを別途作成（既存スレッドへの追加コメントとしては入れない） |

これにより:

- 既存指摘の追跡性が保たれる（同スレッド内に修正履歴が積み上がる）
- 同じ箇所に新規スレッドが乱立しない
- 起票者・PR 閲覧者が「このスレッドはどこまで解消したか」を時系列で把握できる

---

## 2. 4 パターン分岐

再レビュー実行時 / スコープ外指示 / 修正完了指示の受領時、各既存自著スレッドを以下 4 パターンのいずれかに分類する:

```
        ┌─ Pattern A: 解消（自動）
        │    → status = fixed（既定。auto-resolve=false 指定時は reply のみ）
        │    → ✅ 解消確認 reply
        │
        ├─ Pattern C: 未解消 / 自動判定不能
スレッド ─┤    → status は active 維持
        │    → 🔄 再観察 reply
        │
        ├─ Pattern D: ユーザー指示によるスコープ外了承（ack-scope-out=CR-NNN）
        │    → status = wontFix（Azure DevOps）/ resolved（GitHub）
        │    → ✋ スコープ外了承 reply
        │
        └─ Pattern E: ユーザー指示による修正完了確認（ack-fixed=CR-NNN）
             → status = fixed（Azure DevOps）/ resolved（GitHub）
             → ✅ 修正完了 reply（修正コミットへの明示リンク必須）
```

| トリガー | パターン |
|---------|--------|
| 再レビュー実行時の自動判定 | A / C のいずれか |
| ユーザーが `ack-scope-out=CR-NNN` で明示指示 | D（自動判定とは独立に動作） |
| **ユーザーが「修正してください」「対応してください」「全て対応して」等で指示 + Claude が修正コミット作成** | **E（自動判定とは独立に動作）** |

判定の前提となる「解消判定アルゴリズム」は `${CLAUDE_PLUGIN_ROOT}/references/comment-resolution-judge.md`、安全方針（auto-resolve 既定 / 自著限定）は `comment-status-policy.md` を参照。
Pattern D / E の詳細手順は `${CLAUDE_SKILL_DIR}/references/scope-out-acknowledgment.md` を参照。

---

## 3. 各パターンの reply テンプレート（必須要素）

すべての reply には Bot 識別子（`[deep-code-review-plugin]`）が含まれること。Bot 識別子は connector が署名に統合して自動付加する（`signatures.md` 参照）。reply 本文には `🤖` 行を含めず、connector 呼び出し時の args に `marker:` で渡す。

### Pattern A（解消・自動）

```
✅ [deep-code-review-plugin / pr-review] 解消確認（自動判定）
- 再レビュー実施日: <YYYY-MM-DD>
- 対象 head SHA: <sha>
- 判定: コード差分から指摘どおりの修正を確認したため status を fixed に更新しました
- 誤判定の場合は手動でスレッドを再オープンしてください
```

connector 呼び出し時: `marker: [deep-code-review-plugin] auto-resolve (default)`

> `auto-resolve=false` 指定時は status を変更せず、上記 reply の「status を fixed に更新しました」を「解消候補と判定しました（status は未変更）」に差し替えて投稿する。

### Pattern C（未解消・再観察）

```
🔄 [deep-code-review-plugin / pr-review] 再レビュー観察
- 再レビュー実施日: <YYYY-MM-DD>
- 対象 head SHA: <sha>
- 判定: 該当箇所は指摘どおりの修正が確認できませんでした（または自動判定不能）
- スレッドは active のまま維持。修正完了済みの場合は手動で resolve / fixed にしてください
```

connector 呼び出し時: `marker: [deep-code-review-plugin] unresolved; reply only`

### Pattern D（ユーザー指示によるスコープ外了承）

```
✋ [deep-code-review-plugin / pr-review] スコープ外として了承（ユーザー指示）

- 指示日時: <YYYY-MM-DD HH:MM>（<タイムゾーン>）
- Finding ID: <CR-NNN>
- 判定: ユーザーから「本 PR のスコープ外」として了承指示を受領しました
- 本 PR では対応しません。必要に応じて PR 作成者・PdM の判断で別取り組みとして検討されます
```

connector 呼び出し時: `marker: [deep-code-review-plugin] user-acknowledged scope-out`

> Pattern D は **ユーザーの明示指示時のみ** 適用（自動判定では発火しない）。詳細は `scope-out-acknowledgment.md` を参照。

### Pattern E（ユーザー指示による修正完了確認）

```
✅ [deep-code-review-plugin / pr-review] 修正対応完了（ユーザー指示）

- 確認日時: <YYYY-MM-DD HH:MM>（<タイムゾーン>）
- Finding ID: <CR-NNN>
- 対応コミット: [<sha7>](<commit-url>)
- 修正内容: <要約 1〜2 行>
- 判定: ユーザー指示による修正コミット作成を確認・status を fixed に更新しました
- 誤判定の場合は手動でスレッドを再オープンしてください
```

connector 呼び出し時: `marker: [deep-code-review-plugin] user-acknowledged fix`

> Pattern E は **ユーザー修正指示 + Claude による修正コミット作成** が両方成立した場合のみ適用。
> 修正コミットへの明示リンク（`[<sha7>](<commit-url>)`）が **必須**（実証なき status 変更を防ぐ）。
> 詳細は `scope-out-acknowledgment.md` セクション 8 を参照。

---

## 4. 対象スレッドの抽出条件

再レビュー実行時、以下を **すべて** 満たすスレッドのみを対象にする:

| 条件 | 内容 |
|------|------|
| status | `active`（GitHub: `isResolved=false` / Azure DevOps: `status="active"` または `"pending"`） |
| 自著判定 | `comments[0].author.uniqueName` または `login` が現在の認証ユーザーと一致（詳細: `author-identity.md`） |
| インライン | `threadContext.filePath != null`（PR 全体宛のサマリースレッドは対象外） |
| Bot 識別 | （任意）`comments[0].content` に `[deep-code-review-plugin]` が含まれていれば確実に「前回の自分のレビュー」と判別できる。検出対象は本文先頭行（例: `✅ [deep-code-review-plugin / pr-review]`）または末尾署名内（例: `（[deep-code-review-plugin] auto-resolve）`）のいずれか。旧フォーマット（`🤖 [deep-code-review-plugin]` 単独行）も同じ grep でマッチする |

PR 全体宛のサマリースレッド（`threadContext == null`）は **再レビュー対象外**（reply / status 変更を行わない）。
再レビュー時の新しいサマリーは **既存サマリースレッドへの reply ではなく、新規スレッドとして投稿する**（過去サマリーは `status=closed` に更新し、reply は追加しない）。
詳細は `comment-posting.md` セクション 7.5.0 を参照。

---

## 5. API 呼び出し

### 5.1 Azure DevOps / TFS（connector:azure 委譲）

> **委譲設計**: Azure DevOps の全 PR 操作は `connector:azure` に委譲。pr-review から直接 `curl` / `az` コマンドを実行しない。

**reply（既存スレッドへの返信）:**

```text
Skill(skill: "connector:azure", args: "PR URL: <PR_URL> のスレッド <threadId> に返信。本文: <reply_content>。render-check 通過済み。承認済み。")
```

**status 更新（fixed / closed / byDesign など）:**

```text
Skill(skill: "connector:azure", args: "PR URL: <PR_URL> のスレッド <threadId> のステータスを <new_status> に変更。承認済み。")
```

API 実装詳細は connector プラグインの `skills/azure/references/pr-operations.md` を参照。

### 5.2 GitHub（connector:github 委譲）

> **委譲設計**: GitHub の全 PR 操作は `connector:github` に委譲。pr-review から直接 `gh` CLI を実行しない。

**reply（既存コメントへの返信）:**

```text
Skill(skill: "connector:github", args: "PR URL: <PR_URL> のコメント <commentId> に返信。本文: <reply_content>。承認済み。")
```

**status 更新（resolve）:**

```text
Skill(skill: "connector:github", args: "PR URL: <PR_URL> のスレッド <threadId> を resolve。承認済み。")
```

API 実装詳細は connector プラグインの `skills/github/references/pr-operations.md` を参照。

---

## 6. 関連リファレンス

- `comment-status-policy.md` — 安全方針（auto-resolve 既定 / 自著限定 / Bot 識別子）
- `${CLAUDE_PLUGIN_ROOT}/references/comment-resolution-judge.md` — 解消判定アルゴリズム（コード修正系 / テスト追加系 / ドキュメント系）
- `author-identity.md` — 自著判定の詳細（GitHub login / クラウド ADO UPN / NTLM 3 形式）
- `azure-devops-tfs-ntlm.md` セクション 5（status 更新）/ セクション 7（既存スレッドへの reply）— TFS NTLM API
- `github.md` — GitHub の reply / resolve API
