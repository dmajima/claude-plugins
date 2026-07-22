# PR コメントテンプレート（固定・厳守）

PR にインラインコメント・サマリースレッドを投稿する際、本ファイルのテンプレートから組み立てる。
テンプレートの文言は **1 文字の差異も許容しない**（絵文字・スペース・大文字小文字を含む完全一致）。

> **位置付け**: 本ファイルは `comment-posting.md` および SKILL.md Step 7 から参照される。
> 署名・冒頭フォーマット等の静的文言を一元管理し、投稿のたびに手書きで再構成することを禁止する。

---

## 1. 共通署名テンプレート（SIGNATURE）— connector に委譲済み

> **委譲設計**: 署名の付加は **connector プラグインの責務**。pr-review は投稿本文に署名を含めない。connector が投稿前に `references/signatures.md`（SSOT）を自動付加する。操作マーカーが必要な場合は connector 呼び出し時の args に `marker:`（例: `[deep-code-review-plugin] auto-resolve`）を指定する（マーカー定義の SSOT: `comment-status-policy.md` 0.4）。

---

## 2. インラインコメントテンプレート（INLINE）

各指摘ごとの PR インラインコメント本文を以下のテンプレートで組み立てる。

### 2.1 テンプレート構造

```markdown
## [<FINDING_ID>] [<SEVERITY>] <TITLE>

<BODY>
```

> 署名は connector が投稿前に自動付加するため、テンプレートに含めない。

### 2.2 プレースホルダ定義

| プレースホルダ | 説明 | 例 |
|--------------|------|-----|
| `<FINDING_ID>` | Finding ID（`CR-001` 形式） | `CR-001` |
| `<SEVERITY>` | 致命度（`Critical` / `High` / `Medium` / `Low`） | `Critical` |
| `<TITLE>` | 指摘タイトル（短い一文） | `SQL インジェクション可能性` |
| `<BODY>` | 指摘本文（統合サマリの該当セクション内容）。サブ見出しは H3（`###`）以降を使用 | （複数行） |

### 2.3 組み立てルール

1. 1 行目は **必ず** `## [<FINDING_ID>] [<SEVERITY>] <TITLE>` の Markdown H2 見出し
2. ID と致命度はそれぞれ `[ ]` で囲む
3. 本文内のサブ見出し（「指摘内容」「求める修正」「理由・根拠」等）は H3（`###`）以降
4. 本文末尾に署名を含めない（connector が自動付加する）
5. `<BODY>` 内のコード引用は必ずコードフェンスで囲む
6. `<BODY>` 内の `#<数字>` / `@<英数字>` / `!<数字>` は `comment-sanitization.md` セクション 5.5 に従いエスケープ済みであること

---

## 3. サマリースレッドテンプレート（SUMMARY）

サマリースレッド本文は `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/template/output/review-summary.md` の統一テンプレートを使用する（既存ルール）。

本ファイルでは **サマリースレッド固有の補足ルール** のみ定義する。

### 3.1 署名の付与（connector 委譲済み）

サマリースレッドの署名は **connector が投稿前に自動付加** するため、pr-review は本文に署名を含めない。操作マーカーが必要な場合は connector 呼び出し時の args に `marker:` を指定する。

### 3.2 PR 番号の記載

サマリースレッド内で PR 番号を記載する場合:

- **意図的なリンク**: `[PR \#<N>](<PR_URL>)` 形式の明示リンクを使用
- **説明文中**: `\#<N>` でエスケープ、または「PR <N>」のように `#` を使わない表現

---

## 4. テンプレート組み立てフロー

```
統合サマリ本文（CR-001 〜 CR-NNN 採番済み）
  ↓
各 Finding ID ごとに以下を組み立て:
  1. セクション 2 のインラインテンプレートに値を埋め込み
  2. comment-sanitization.md セクション 3-5.5 のサニタイズを適用
  3. 本文末尾に署名を含めない（connector が投稿時に自動付加する）
  4. SKILL.md Step 7 の投稿前バリデーションチェックリスト（4 項目）を通過
  ↓
インラインコメントを CR-001, CR-002, ... の順に投稿
  ↓
全インライン投稿完了後、サマリースレッドを組み立て:
  1. review-summary.md テンプレートに値を埋め込み
  2. Finding ID リンクを埋め込み（インライン投稿後に thread_id が確定）
  3. サニタイズ + 投稿前バリデーション（署名は含めない・connector が自動付加）
  4. 旧サマリーを closed → 新サマリーを POST
```

---

## 5. 禁止事項

- 投稿本文に署名を含めること（署名は connector が投稿前に自動付加するため、pr-review は本文に署名を付加・再構成してはならない）
- インラインコメントの冒頭フォーマットをテンプレート以外の形式で記述すること
- connector が付加する署名を pr-review 側で二重に付加すること
- テンプレートのプレースホルダ以外の部分を変更すること（固定文言の改変禁止）

---

## 6. 関連リファレンス

- `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/template/output/review-summary.md` — サマリーテンプレート（SSOT）
- `${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` — サニタイズ規則
- `${CLAUDE_SKILL_DIR}/references/comment-posting.md` — 投稿の詳細実装
- `${CLAUDE_SKILL_DIR}/SKILL.md` Step 7 — 投稿前バリデーションチェックリスト
