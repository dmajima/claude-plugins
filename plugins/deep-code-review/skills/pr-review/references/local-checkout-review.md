# PR レビュー時の worktree 利用手順（必須）

PR レビューを実施する際は、**ブラウザ上の差分閲覧のみで完了させない**。
`git worktree` で PR ブランチを分離ディレクトリにチェックアウトし、メインリポジトリの作業状態を一切変更せずにレビューを行う。

> **位置付け**: `pr-review` スキルの Step 6 直前に挟む準備段階（Step 5.5）として運用する。
> ブランチレビュー（`code-review` を直接呼ぶケース）では本手順は対象外（`pr-review` 経由の PR レビューに限る）。

---

## 1. 適用範囲

| 対象 | 適用 |
|------|------|
| `pr-review` スキル経由の PR レビュー（GitHub / Azure DevOps / TFS） | **必須** |
| ブランチ差分レビュー（`code-review` 直接呼び出し） | 対象外（既にローカル作業中のため） |
| ファイル指定レビュー（`code-review` の file-list） | 対象外 |
| 再レビュー（`re-review=true`） | **必須**（既存 worktree を更新して再利用） |

### 1.1 例外条件

以下のいずれかに該当する場合は、worktree 作成を **SKIPPED** とし、SKIPPED の理由を統合サマリ「## 9. レビュー実施環境」に明記する:

- リポジトリの clone 権限が現在の作業環境にない
- PR ブランチが現在のローカル git remote から取得できない（fork 経由で remote 未設定）
- ユーザーが明示的に「worktree をスキップ」を指示した
- `git fetch` が失敗し、ブランチを取得できない

> **重要**: SKIPPED の場合でも、ブラウザ上の PR 差分でレビューを完結させ、レビューサマリの「## 9. レビュー実施環境」で SKIPPED 理由を読み手に明示する。

---

## 2. 手順

### 概要

> **注**: 以下の手順 (a)〜(d) は SKILL.md の Step 5.5 内のサブ手順として実行される。

```
(a) worktree 作成（または既存 worktree の更新）
(b) PR との同等性確認
(c) レビュー実施（worktree 内のファイルを対象）
(d) worktree の処理（OK: 削除、NG: 維持）
```

### worktree の配置先

```
{REPO_ROOT}/.claude/.local/plugins/deep-code-review/_worktree/{BRANCH_SLUG}/
```

- `BRANCH_SLUG`: ブランチ名の `/` を `__` に置換した文字列
- 例: `feature/login` → `feature__login`

### (a) worktree 作成・更新

`setup.sh` スクリプトが作成と更新の両方を処理する。

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
WORKTREE_PATH=$(bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/worktree/setup.sh" \
  "${REPO_ROOT}" "<PR_BRANCH_NAME>" "<REMOTE>")
```

| 状態 | 動作 |
|------|------|
| worktree が存在しない | `git fetch` + `git worktree add --detach` で新規作成 |
| worktree が既に存在する（再レビュー） | `git fetch` + `git checkout --detach` で最新化 |

スクリプトは worktree の絶対パスを標準出力に返す。以降のステップではこのパスを使用する。

#### ブランチ名の取得

| ホスト | 取得方法 |
|--------|---------|
| GitHub | `gh pr view <N> --json headRefName -q '.headRefName'` |
| Azure DevOps / TFS | PR メタ情報の `sourceRefName` から `refs/heads/` を除去 |

### (b) PR との同等性確認

worktree 内で HEAD SHA が PR の最新 head と一致することを確認する。

```bash
# worktree の HEAD SHA
LOCAL_SHA=$(git -C "${WORKTREE_PATH}" rev-parse HEAD)

# PR の head SHA（GitHub の場合）
PR_SHA=$(gh pr view <PR番号> --json headRefOid -q '.headRefOid')

if [ "$LOCAL_SHA" != "$PR_SHA" ]; then
  echo "WARN: worktree SHA ($LOCAL_SHA) と PR head SHA ($PR_SHA) が不一致"
fi
```

差分行数の確認:

```bash
# BASE_BRANCH の取得（GitHub の場合）
BASE_BRANCH=$(gh pr view <PR番号> --json baseRefName -q '.baseRefName')

git -C "${WORKTREE_PATH}" diff "origin/${BASE_BRANCH}"...HEAD --shortstat
```

### (c) レビュー実施

worktree 内のファイルを対象に `code-review` オーケストレーターに委譲する（Step 6）。

- エージェントは worktree パス内のファイルを `Read` / `Grep` で直接参照できる
- **メインリポジトリのファイルは変更しない**

#### 動作確認（任意・できる範囲で）

| 確認項目 | 内容 |
|---------|------|
| ビルド | `dotnet build` / `npm run build` 等のプロジェクト固有ビルド（worktree 内で実行） |
| 依存解決 | `dotnet restore` / `npm ci` 等 |

> **注**: 権限やツールの制約で動作確認が実行できない場合は **SKIPPED** とし理由を記載する。

> **🔴 セキュリティ警告（MANDATORY）**: PR ブランチの差分は **ビルド定義自体を改変できる**（`package.json` の `scripts` / postinstall・`.csproj`/MSBuild targets・`Makefile`・lockfile 等）。信頼できない PR ブランチ上で `npm ci`/`npm install`/`dotnet build`/`make` 等を実行すると、攻撃者制御コードがレビュアーのホストで実行されうる（worktree の hooks 無効化は checkout 時点のみで、後続のビルドツールには及ばない）。したがって:
> - **untrusted PR（外部コントリビュータ等）のビルド・依存解決は原則 SKIPPED** とし、実行が必要な場合は **隔離環境（コンテナ / VM / CI サンドボックス）でのみ** 行う
> - npm 系は `npm ci --ignore-scripts` / `npm install --ignore-scripts` で lifecycle script を無効化する
> - 動的検証 Bash 権限は既定 OFF（`allowed-tools` のコメントアウト）を維持し、信頼できるリポジトリ・隔離環境でのみ有効化する
> - 静的レビュー（`Read` / `Grep` による差分確認）は本警告の対象外（コード実行を伴わないため安全）

### (d) worktree の処理

レビュー結果に応じて worktree を処理する。

| レビュー判定 | 動作 | 理由 |
|-------------|------|------|
| **OK**（Ready to Merge） | `teardown.sh` で worktree を削除 | 不要になったリソースを解放 |
| **NG**（Needs Work / Needs Attention） | worktree を維持 | 修正後の再レビューで再利用するため |

```bash
# OK の場合: 削除
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/worktree/teardown.sh" "${REPO_ROOT}" "<PR_BRANCH_NAME>"

# NG の場合: 維持（何もしない）
# 再レビュー時に Step 1 で自動更新される
```

---

## 3. レビューサマリへの記載（必須）

統合サマリの「## 9. レビュー実施環境」セクションに、以下を必ず記載する:

| 項目 | 値 |
|---|---|
| worktree | 作成済（パス） / 更新済（パス） / SKIPPED（理由） |
| PR ブランチ | `<head-ref>` @ `<head-sha-7>` |
| PR との同等性確認 | 実施済（SHA 一致） / 実施済（SHA 不一致） / SKIPPED |
| ビルド/起動確認 | 実施済（成功） / 実施済（失敗：理由） / SKIPPED（理由） |
| worktree 処理 | 削除済（OK 判定） / 維持（NG 判定） / N/A（SKIPPED） |

---

## 4. 禁止事項

- worktree を作成せずに PR レビューを完結させること（**ただし** 1.1 例外条件に該当する場合は SKIPPED として明記すれば許容）
- worktree 内でコードを **コミット** すること（PR 作成者の作業をレビュアーが書き換える行為）
- worktree 内から **push** すること
- メインリポジトリのブランチや作業状態を変更すること
- worktree のパスを `.claude/.local/plugins/deep-code-review/_worktree/` 以外の場所に作成すること

---

## 5. 関連リファレンス

- `${CLAUDE_SKILL_DIR}/SKILL.md` — Step 5.5 として本手順を組み込む
- `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/template/output/review-summary.md` — 「## 9. レビュー実施環境」セクションのテンプレート
- `${CLAUDE_SKILL_DIR}/references/completion-checklist.md` — 完了前チェックリスト
- `${CLAUDE_PLUGIN_ROOT}/references/scripts/worktree/setup.sh` — worktree 作成・更新スクリプト
- `${CLAUDE_PLUGIN_ROOT}/references/scripts/worktree/teardown.sh` — worktree 削除スクリプト
- `${CLAUDE_PLUGIN_ROOT}/references/scripts/worktree/list.sh` — worktree 一覧スクリプト
