# コメントステータス操作の安全方針

`pr-review` スキルが PR 内のコメント/スレッドのステータスを更新する際の **安全方針・禁止事項** をまとめたファイル。

> **位置付け**: 旧 `comment-status.md` セクション 0 / 3 から分離。本ファイルは「LLM 判定による誤動作を防ぐためのガード」に特化。再レビュー時の動作仕様は `re-review-flow.md`、解消判定アルゴリズムは `${CLAUDE_PLUGIN_ROOT}/references/comment-resolution-judge.md` を参照。

---

## 0. 基本原則

LLM 判定による誤動作で **他者の指摘を勝手に解消してしまう** リスクが高いため、以下を **既定動作として強制** する。

ホスティングサービスの **ネイティブなスレッド/レビューステータス機能** を使う。コメント本文に独自マーカー（例: `[Resolved]`）を埋め込んで管理する方式は **禁止**。

---

## 0.1 auto-resolve が既定

ユーザーが明示的に `auto-resolve=false` を指定しない限り、**解消確認できたスレッドのステータス更新まで実施する**。
`auto-resolve=false` 指定時は解消候補のレポート（reply）のみ生成する。

```
# 既定（auto-resolve）
PR #123 をレビューして
  → 解消確認できたスレッドは reply + status=fixed まで実施。ただし以下のガードあり。

# auto-resolve=false で dry-run
PR #123 をレビューして auto-resolve=false
  → 解消判定の結果のみ報告（reply）。ステータス更新なし。
```

---

## 0.2 自著スレッドのみ resolve（必須）

**他者（人間レビュアー）が起票したスレッドは自動 resolve しない**。

判定ロジックの詳細実装（GitHub `login` / クラウド ADO UPN / オンプレ TFS NTLM の 3 形式・空文字ガード・大文字小文字無視）は **`${CLAUDE_SKILL_DIR}/references/author-identity.md` を参照**。

要点:

1. スレッドの最初のコメントから一意識別子を取得（`uniqueName` / `login`）
2. 現在の認証ユーザーと **大文字小文字を無視して** 照合（空文字ガード必須）
3. **一致する場合のみ** resolve 候補にする
4. 一致しない場合は「未解決のまま、手動確認推奨」としてレポート

> ⚠️ `displayName` での比較は禁止（表示名変更可能・なりすまし可能）。

---

## 0.3 廃止（キーワード除外・欠番）

本セクションは **欠番** であり、現行の規範は存在しない（参照互換のため節番号のみ維持）。

> 改定注記: 旧 0.3「Critical/High キーワードを含むスレッドは常に未解決」は撤廃済み（運用方針: 人間レビューは AI レビュー完了後に実施するため）。ルール ID 軸では P11 の廃止に対応（`${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md`）。

---

## 0.4 ステータス更新時は Bot 識別子付き返信を必須

resolve / fixed に変更する場合、**スレッドへの返信コメント** で以下を必ず添える:

```
自動判定: コード差分から解消候補と判断し、ステータスを更新しました。
判定理由: <要約>
誤判定の場合は手動で再オープンしてください。
```

connector 呼び出し時に `marker: [deep-code-review-plugin] auto-resolve` を指定し、署名に Bot 識別子を統合する（`signatures.md` 参照）。
この返信により、人間レビュアーは「いつ・なぜ・誰の判断で resolve されたか」を追跡できる。

具体的な reply テンプレートは `re-review-flow.md` の 4 パターン分岐参照（Pattern A: 自動解消 / Pattern C: 未解消 / Pattern D: ユーザー指示によるスコープ外了承 / Pattern E: ユーザー指示による修正完了確認）。

---

## 0.5 ユーザー指示によるスコープ外了承（Pattern D・MANDATORY）

ユーザーが Finding ID を指定して「スコープ外として対応」と指示した場合のみ、対応スレッドにコメントを投稿したうえで status を `wontFix`（Azure DevOps）/ resolve（GitHub）に更新する。

### 安全方針

| 項目 | 方針 |
|------|------|
| トリガー | **ユーザーの明示指示のみ**（自動判定禁止） |
| `auto-resolve=false` 指定 | **影響しない**（ユーザー指示のため即時実行） |
| 自著限定 | **適用する**（自著スレッドのみ。他者起票は触らない） |

### 詳細

詳細手順・引数仕様・リプライテンプレート・最終状態検証は `${CLAUDE_SKILL_DIR}/references/scope-out-acknowledgment.md` を参照。

---

## 0.5.E ユーザー指示による修正完了確認（Pattern E・MANDATORY）

ユーザーが Finding ID を指定して「修正してください」「対応してください」「全て対応してください」等と指示し、**Claude がコードを実際に修正・コミットした場合**、対応スレッドにコメントを投稿したうえで status を `fixed`（Azure DevOps）/ resolve（GitHub）に更新する。

### 動機

Pattern A（自動判定）は再レビュー時のコード差分から「解消されているか」を LLM が推測して status を更新する（`auto-resolve=false` 指定時は reply のみ）。
これに対し Pattern E は **ユーザーの明示指示で Claude 自身が修正コミットを作成した場合** の運用で、修正の事実が確実なため解消判定を経ずに status を即時 `fixed` 化する。

### 安全方針

| 項目 | 方針 |
|------|------|
| トリガー | **ユーザーの修正指示 + Claude による修正コミット作成** が両方成立した場合のみ |
| 修正コミットへのリンク | reply に **必ず明示リンク** で含める（実証ありを表す） |
| 自動判定 | **行わない**（修正事実があってもコード解消判定までは行わず、コミット参照で根拠を示す） |
| `auto-resolve=false` 指定 | **影響しない**（ユーザー指示 + 修正コミットありのため即時実行） |
| 自著限定 | **適用する**（自著スレッドのみ。他者起票は触らない） |

### Pattern A との使い分け

| 状況 | 使うパターン | 動作 |
|------|------------|------|
| 再レビュー実行時に LLM がコード差分から解消判定 | **Pattern A**（auto-resolve 既定） | 既定で status=fixed（`auto-resolve=false` 指定時は reply のみ） |
| ユーザーが修正指示 → Claude が修正コミット → 完了確認 | **Pattern E** | 即時 status=fixed |
| ユーザーがスコープ外として了承 | **Pattern D** | 即時 status=wontFix |

### 詳細

詳細手順・引数仕様（`ack-fixed=CR-NNN[,CR-NNN...]`）・リプライテンプレート・最終状態検証は `${CLAUDE_SKILL_DIR}/references/scope-out-acknowledgment.md` セクション 8（Pattern E 仕様）を参照。

---

## 0.6 auto-resolve=false 指定時のレポート形式

`auto-resolve=false` 指定時（dry-run）は、レポートに「解消候補（更新せず）」「自著確認 OK / NG」を併記する:

```markdown
## 未解決コメントの解消判定（dry-run）

### 解消候補（更新せず・手動判断推奨）
1. `<file>:<line>` — 「<要約>」
   - 自著: ✅（今回のレビュー実行アカウントと一致）
   - 判定: 解消とみなす根拠あり（コードが指摘どおり修正されている）

### 解消候補だが自動 resolve 対象外
2. `<file>:<line>` — 「<要約>」
   - 自著: ❌（他者が起票）
   - 判定: 解消されているように見えるが、起票者の判断が必要
```

---

## 3. 禁止事項

- コメント本文に独自マーカー（`[Resolved]` 等）を埋め込んで管理すること
- ホスティングサービスのネイティブステータス機能を使わずにメッセージで管理すること
- 判定が曖昧なまま自動でステータスを更新すること
- 設計・仕様・質問系のコメントを自動で解消扱いにすること
- **他者（人間レビュアー）が起票したコメントを LLM 判定で resolve すること**（セクション 0.2 / `author-identity.md`、自著のみ許可）
- **`auto-resolve=false` 指定時にステータス更新すること**（セクション 0.1）
- **resolve 実施後に Bot 識別子付き返信を残さないこと**（セクション 0.4）
- **ユーザー指示なしに Pattern D（スコープ外了承）を実行すること**（セクション 0.5）
- **Claude が修正コミットを作成したのに Pattern E（修正完了確認）を実行せず status=active のまま放置すること**（セクション 0.5.E）
- **Pattern E 実行時に修正コミットへの明示リンクを reply に含めないこと**（実証なき status 変更の禁止）

---

## 関連リファレンス

- `re-review-flow.md` — 再レビュー時の動作仕様（4 パターン分岐 + reply テンプレ）
- `${CLAUDE_PLUGIN_ROOT}/references/comment-resolution-judge.md` — 解消判定アルゴリズム（コード修正系/テスト追加系/ドキュメント系）
- `author-identity.md` — 自著判定の詳細（GitHub/クラウド ADO/NTLM の 3 形式統一）
