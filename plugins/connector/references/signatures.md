# 投稿署名（SSOT）

外部サービスへのコメント投稿時に本文末尾に付与する署名の一元定義。

**本ファイルが署名の唯一の定義元（SSOT）**。各プラグイン（code-review / coding 等）は自身のテンプレートに署名を持たず、connector が投稿前に自動付加する。

## 1. 署名テンプレート

### 1.1 汎用署名（全サービス共通）

全投稿の末尾に付与する共通署名。呼び出し元プラグインの種別を問わず適用する。

```
🤖 Generated with [Claude Code](https://claude.ai/claude-code)
```

### 1.2 操作マーカー（任意・呼び出し元が指定）

汎用署名に加えて、投稿の種別を識別するマーカー。呼び出し元が args で `marker: <マーカー文字列>` を指定した場合に、汎用署名の末尾に全角括弧で付記する。

```
🤖 Generated with [Claude Code](https://claude.ai/claude-code)（[{マーカー文字列}]）
```

呼び出し元が指定するマーカーの例:

| 呼び出し元 | 操作 | マーカー |
|-----------|------|---------|
| code-review (pr-review) | 自動解消確認 reply | `[code-review-plugin] auto-resolve (default)` |
| code-review (pr-review) | 未解消 reply | `[code-review-plugin] unresolved; reply only` |
| code-review (pr-review) | スコープ外了承 | `[code-review-plugin] user-acknowledged scope-out` |
| code-review (pr-review) | 修正完了確認 | `[code-review-plugin] user-acknowledged fix` |
| coding (orchestrator-fix) | 修正対応返信 | `[orchestrator-fix] fix-reply` |
| coding (orchestrator-fix) | 修正対応サマリ | `[orchestrator-fix] fix-summary` |

マーカーを指定しない場合は汎用署名のみ付与する。

## 2. 署名の付加ルール

### 2.1 付加タイミング

connector の書き込み系操作（コメント投稿・スレッド返信）の **実行直前** に、投稿本文の末尾に署名を自動付加する。

### 2.2 付加条件

| 条件 | 動作 |
|------|------|
| 投稿本文に既に汎用署名が含まれている | 二重付加しない（スキップ） |
| 投稿本文に署名が含まれていない | 末尾に空行 1 行 + 署名を付加 |
| ステータス変更（書き込み・本文なし） | 署名付加の対象外 |
| 読み取り操作 | 署名付加の対象外 |

### 2.3 付加フォーマット

マーカーなしの場合:

```
{投稿本文}

🤖 Generated with [Claude Code](https://claude.ai/claude-code)
```

マーカーありの場合:

```
{投稿本文}

🤖 Generated with [Claude Code](https://claude.ai/claude-code)（[{マーカー文字列}]）
```

## 3. 署名検証

投稿前に以下を検証する:

- 汎用署名がテンプレート（セクション 1.1）と **完全一致** であること（絵文字・スペース・大文字小文字を含む）
- マーカーが指定されている場合、汎用署名の末尾に `（[{マーカー文字列}]）` が全角括弧で付記されていること（署名は常に 1 行）
- 署名が本文の最終行に位置すること（署名の後に本文テキストがないこと）

## 4. 呼び出し元の責務変更

本ファイルにより、各呼び出し元プラグインは以下の変更を適用する:

| 呼び出し元 | 変更前 | 変更後 |
|-----------|--------|--------|
| code-review (pr-review) | 投稿前バリデーション SIGNATURE 項目で署名の完全一致を検証し、テンプレートから転記 | **署名の付加を行わない**。投稿前バリデーションの SIGNATURE 項目は削除。connector が自動付加 |
| coding (orchestrator-fix) | テンプレート内に署名を含めて組み立て | **署名を本文に含めない**。connector が自動付加。マーカーが必要な場合は args に `marker:` を指定 |

## 5. 対象サービス

| サービス | 署名付加 | 備考 |
|---------|---------|------|
| Azure DevOps（PR コメント・作業項目コメント） | 付加する | Markdown 記法でレンダリングされる |
| GitHub（PR コメント・レビューコメント） | 付加する | Markdown 記法でレンダリングされる |
| Backlog（課題コメント） | 付加する | Backlog 記法 / Markdown 記法に応じてレンダリング |
| Slack（メッセージ） | 付加しない | Slack は独自のフォーマットで Bot 識別が表示される |
| Google Workspace | 付加しない | ファイル操作のため署名対象外 |
| ProjectBoard | 付加しない | タスク操作のため署名対象外 |
| ailead | 付加しない | 読み取り専用 |
