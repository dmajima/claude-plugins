---
description: PR レビュー用 worktree の一覧表示・対話削除
allowed-tools:
  - AskUserQuestion
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/references/scripts/worktree/*.sh *)
  - Bash(git *)
---

PR レビュー時に作成された git worktree を一覧表示し、対話的に削除する。

## 使い方

```
/clear-worktree
```

引数: `$ARGUMENTS`（なし）

## 実行手順

### 1. 一覧取得

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/worktree/list.sh" "${REPO_ROOT}"
```

出力はタブ区切り `branch_name\ttimestamp\tpath`（古い順）。0 行なら「PR レビュー用の worktree はありません」と報告して終了。

### 2. 削除対象の確認

`AskUserQuestion` で削除対象を選択させる。

- **最初の選択肢**: 「一括削除」（description に全件数を表示）。ただし **worktree が 1 件のみの場合は「一括削除」を省略** し、該当ブランチの個別選択肢のみ提示する（同一結果の選択肢重複を避けるため）
- **残りの選択肢**: ブランチ名を label に、作成日時を description に表示。作成日時が **古い順** に最大 3 件
- 作成日時は `.worktree-meta` の ISO8601 UTC 値を `YYYY-MM-DD HH:MM (UTC)` 形式に整形して表示する（生の `2026-06-01T14:23:00Z` のまま表示しない）
- `AskUserQuestion` の options 上限は 4 件（ツール仕様: `maxItems: 4`）。worktree が 4 件以上ある場合は「一括削除」+ 古い順 3 件を表示
- 表示しきれない worktree はユーザーが「Other」でブランチ名を直接入力して指定できる

### 3. 削除実行

```bash
# 一括削除
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/worktree/teardown.sh" "${REPO_ROOT}" --all

# 個別削除
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/worktree/teardown.sh" "${REPO_ROOT}" "<branch_name>"
```

### 4. 結果報告

削除した worktree のブランチ名と件数を報告する。
