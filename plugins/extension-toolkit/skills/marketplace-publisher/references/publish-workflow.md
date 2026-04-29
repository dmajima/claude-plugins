# 公開ワークフロー詳細

ハンドオフモードとフルオートモードの実行手順。

## モード A: ハンドオフフォーマット

ユーザが「1. ハンドオフ」を選択した場合に提示する内容。

### 提示する項目

1. **変更ファイル一覧**
2. **marketplace.json の差分**
3. **推奨コミットメッセージ**
4. **次のコマンド**
5. **PR 作成リンク**（branch 名がわかる場合）

### フォーマット例

```text
## 変更ファイル

- 新規: plugins/{plugin-name}/.claude-plugin/plugin.json
- 新規: plugins/{plugin-name}/README.md
- 新規: plugins/{plugin-name}/skills/{skill-name}/SKILL.md
- 更新: .claude-plugin/marketplace.json

## marketplace.json の差分

(追加されたエントリの JSON を表示)

## 次のステップ

```bash
git status
git add plugins/{plugin-name} .claude-plugin/marketplace.json
git commit -m "Add plugin: {plugin-name}"
git push origin <branch>
```

## PR 作成

main は保護ブランチのため、必ずフィーチャーブランチで作業し PR を作成してください:

{リモート種別に応じた PR 作成 URL}
```

### 制約

- main への直接 push は不可。フィーチャーブランチを使うようユーザに案内
- 「コミット以降はユーザが実施」と明示

## モード B: フルオートモード手順

ユーザが「2. フルオート」を選択した場合に実行する手順。

### 1. 現在のブランチ確認

```bash
git branch --show-current
```

| 結果 | 動作 |
|-----|------|
| `main` または `master` | フルオートを **中断**、フィーチャーブランチへの切り替えを依頼 |
| その他 | 進行 |

### 2. リモート種別判定

`git remote -v` でリモート URL を取得し、以下を判定:

| パターン | リモート種別 | PR 作成方法 |
|---------|------------|------------|
| `github.com` | GitHub | `gh pr create` |
| `tfs.*` | TFS / Azure DevOps | TFS MCP `tfs_create_pull_request` |
| その他 | 不明 | ユーザに確認 |

### 3. git add & commit

```bash
git add plugins/{plugin-name} .claude-plugin/marketplace.json
git commit -m "Add plugin: {plugin-name}"
```

コミットメッセージは以下の形式:

| シナリオ | コミットメッセージ |
|---------|-----------------|
| 新規登録 | `Add plugin: {plugin-name}` |
| 既存更新 | `Update plugin: {plugin-name}` |
| 削除 | `Remove plugin: {plugin-name}` |

### 4. git push

```bash
git push origin <branch>
```

リモートが上流追跡なしの場合は `git push -u origin <branch>`。

### 5. PR 作成

#### GitHub の場合

```bash
gh pr create \
  --title "Add plugin: {plugin-name}" \
  --body "{PR 説明}" \
  --base main
```

#### TFS の場合

`tfs_create_pull_request` を呼び出す:

| パラメータ | 値 |
|-----------|---|
| `collection` | プロジェクトコレクション |
| `repo_id` | リポジトリ GUID |
| `source_branch` | 現在のブランチ名 |
| `target_branch` | `main` |
| `title` | `Add plugin: {plugin-name}` |
| `description` | 変更ファイル一覧 + 利用者向けインストール手順 |

### 6. PR URL を提示

```text
PR 作成完了: {PR URL}

マージ後の利用者向けインストール手順:
  /plugin marketplace add {marketplace-url}
  /plugin install {plugin-name}@{marketplace-name}
```

### 制約

- フルオート実行前に必ず **ユーザの明示的選択**（「2」または「フルオート」）があること
- main / master 直接 push は禁止
- `git commit` 失敗時（nothing to commit 等）はエラーを提示してユーザに確認
- リモート種別不明時はハンドオフにフォールバック

## エラー時のリカバリ

| エラー | リカバリ |
|-------|---------|
| `git commit` で nothing to commit | 既にコミット済み、push のみ実行 |
| `git push` で rejected | `git pull --rebase` を提案、解決後に再 push |
| PR 作成失敗 | ハンドオフに切り替え、PR 作成 URL を提示 |
| 認証エラー | ユーザに認証情報の確認を依頼（`credentials-manager` スキルへの接続を提案） |

## PR 説明テンプレート

```markdown
## 概要

{plugin-name} プラグインを {新規追加 / 更新} します。

## 変更内容

- {変更点 1}
- {変更点 2}

## 利用方法

```text
/plugin install {plugin-name}@{marketplace-name}
```

## 動作確認

- {確認手順 1}
- {確認手順 2}
```
