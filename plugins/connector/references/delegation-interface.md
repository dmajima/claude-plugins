# 委譲インターフェース仕様（SSOT）

外部プラグインが connector の各スキルを `Skill(skill: "connector:<skill>", args: "...")` で呼び出す際の **args フォーマット仕様**。

**本ファイルが args フォーマットの唯一の定義元（SSOT）**。呼び出し元プラグイン（code-review / coding / investigation 等）が args を構築する際は、本ファイルのフォーマットに従うこと。connector 側の各 SKILL.md「委譲操作テーブル」も本ファイルに準拠する。

## 1. 共通フォーマット

```
Skill(skill: "connector:<skill>", args: "<操作指示>。[ゲートスキップキーワード]。[marker: <マーカー>]")
```

### 1.1 ゲートスキップキーワード

| キーワード | 効果 | 使用条件 |
|-----------|------|---------|
| `読み取りのみ` | 安全ゲート全スキップ（読み取り系と判定） | 読み取り操作時 |
| `render-check 通過済み` | render-check ゲートをスキップ | 呼び出し元が render-check を実施済みの場合（Azure DevOps / Backlog のみ） |
| `承認済み` | AskUserQuestion 承認をスキップ | 呼び出し元がユーザー承認を取得済みの場合 |

キーワードは args 文字列内に日本語で含める。複数指定時はピリオド区切り。

### 1.2 marker オプション

`marker: [xxx] yyy` を args 末尾に含めると、signatures.md の操作マーカーとして署名に挿入される。

例: `marker: [orchestrator-fix] fix-reply`

### 1.3 フォーマット変更時の影響範囲

本ファイルのフォーマットを変更する場合、以下のファイルの args 例も同期更新が必要:

| プラグイン | ファイル | 該当セクション |
|-----------|---------|---------------|
| connector | `skills/azure/SKILL.md` | 「対応する委譲操作」テーブル |
| connector | `skills/github/SKILL.md` | 「対応する委譲操作」テーブル |
| code-review | `skills/pr-review/references/comment-posting.md` | セクション 7.1 / 7.2 |
| code-review | `skills/pr-review/references/re-review-flow.md` | セクション 5.1 / 5.2 |
| code-review | `skills/pr-review/references/azure-devops.md` | 「委譲パターン」セクション |
| coding | `skills/orchestrator-fix/SKILL.md` | Step 5 の connector 呼び出し |
| coding | `skills/orchestrator-fix/references/procedures.md` | セクション 7 |
| coding | `skills/orchestrator-merge/references/merge-target.md` | 方法 2 |
| investigation | `references/collaboration-rules.md` | セクション 5.1 / 5.2 |

## 2. スキル別フォーマット

### 2.1 connector:azure

| 操作 | args フォーマット |
|------|-----------------|
| PR 情報取得 | `読み取りのみ。PR URL: <url> の PR メタ情報を取得して` |
| スレッド一覧取得 | `読み取りのみ。PR URL: <url> のスレッド一覧を取得して` |
| インラインコメント投稿 | `PR URL: <url> にインラインコメントを投稿。ファイル: <path>, 開始行: <n>, 終了行: <m>, 本文: <content>。render-check 通過済み。承認済み。` |
| 全体コメント投稿 | `PR URL: <url> にコメントスレッドを投稿。本文: <content>。render-check 通過済み。承認済み。` |
| 既存スレッドへの返信 | `PR URL: <url> のスレッド <threadId> に返信。本文: <content>。render-check 通過済み。承認済み。` |
| スレッドステータス変更 | `PR URL: <url> のスレッド <threadId> のステータスを <status> に変更。承認済み。` |
| commit 情報取得 | `読み取りのみ。<org-url> のリポジトリ <repo> の commit <commitId> の詳細・変更ファイル一覧を取得して` |
| Pipelines ビルド結果取得 | `読み取りのみ。<org-url> のプロジェクト <project> のビルド <buildId> の結果・テスト結果・ログを取得して` |
| 認証ユーザー ID 取得 | `読み取りのみ。<url> の認証ユーザー（自分）の ID を取得して` |

### 2.2 connector:github

| 操作 | args フォーマット |
|------|-----------------|
| PR 情報取得 | `読み取りのみ。PR URL: <url> の PR メタ情報を取得して` |
| PR diff 取得 | `読み取りのみ。PR URL: <url> の diff を取得して` |
| スレッド一覧取得 | `読み取りのみ。PR URL: <url> のレビュースレッド一覧を取得して` |
| インラインコメント投稿 | `PR URL: <url> にインラインコメントを投稿。ファイル: <path>, 開始行: <n>, 終了行: <m>, commit: <sha>, 本文: <content>。承認済み。` |
| Pending Review 一括投稿 | `PR URL: <url> に Pending Review を投稿。サマリー: <summary>, コメント: <json_array>。承認済み。` |
| PR 全体コメント投稿 | `PR URL: <url> にコメントを投稿。本文: <content>。承認済み。` |
| スレッド resolve | `PR URL: <url> のスレッド <threadId> を resolve。承認済み。` |
| スレッド unresolve | `PR URL: <url> のスレッド <threadId> を unresolve。承認済み。` |
| 既存コメントへの返信 | `PR URL: <url> のコメント <commentId> に返信。本文: <content>。承認済み。` |

### 2.3 connector:backlog

| 操作 | args フォーマット |
|------|-----------------|
| 課題取得 | `読み取りのみ。<課題 URL または課題キー> の件名・本文・コメントを取得して` |
| 課題検索 | `読み取りのみ。<スペース> で「<キーワード>」に関する課題を検索して` |
| コメント投稿 | `<課題 URL または課題キー> にコメント投稿。本文: <content>` |
| ステータス更新 | `<課題 URL または課題キー> のステータスを <status> に変更` |

## 3. サブエージェント呼び出し（read + 後続フローあり）

read 系操作を **後続フローのある文脈で** 呼び出す場合は、`Skill()` ではなく `Agent()` を使用すること。
`Skill()` では connector スキルの結果報告後に呼び出し元のフローが停止する問題がある。

詳細なプロトコル・テンプレート・パラメータは **[subagent-protocol.md](subagent-protocol.md)** を参照。

### 使い分けの判定

| 後続フロー | 操作種別 | 方式 | 参照先 |
|-----------|---------|------|--------|
| **あり**（取得データを使って処理を続ける） | read | `Agent()` + ファイル受け渡し | `subagent-protocol.md` |
| **なし**（取得して報告で完了） | read | `Skill()` / コマンド（従来通り） | 本ファイル セクション 2 |
| あり/なし | write | `Skill()` 委譲（従来通り） | 本ファイル セクション 2 |

### 概要

1. 呼び出し元がセッション作業領域に出力ディレクトリを準備（`.claude/.local/work/{session}/workspace/connector/`）
2. `Agent()` でサブエージェントを起動（`subagent-protocol.md` のテンプレートを使用）
3. サブエージェントが内部で `Skill()` を実行し、結果をファイル出力
4. サブエージェントがマニフェスト（ファイルパス + 概要）を返却
5. 呼び出し元が後続フローを続行

## 4. バージョニング

本ファイルのフォーマットを変更する場合:

1. 本ファイルを更新する
2. セクション 1.3 の影響範囲テーブルに記載された全ファイルの args 例を同期更新する
3. サブエージェントプロトコル変更時は `subagent-protocol.md` セクション 7 の影響範囲も同期更新する
4. connector の plugin.json version をマイナーバージョンアップする
