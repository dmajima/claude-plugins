---
description: 全マーケットプレイス・プラグインを順序付きで一括更新（User/Project/Local 個別処理）
argument-hint: "[--dry-run] [--scope user|project|local|all]"
---

ユーザの引数: $ARGUMENTS

インストール済みマーケットプレイスとそこから導入されたプラグインを **一括で最新版に更新** するコマンド。
**マーケットプレイス更新 → User → Project → Local の固定順** で処理し、同一プラグインが複数スコープに
存在する場合も **スコープごとに個別に更新** する。

## 動作モード判定

| 引数 | モード | 動作 |
|-----|-------|------|
| 空 | 通常更新 | 全フェーズを実行 |
| `--dry-run` 含む | 確認のみ | 各フェーズの対象一覧を表示。実際の更新は行わない |
| `--scope user` / `--scope project` / `--scope local` | スコープ限定 | マーケットプレイス更新後、指定スコープのみ処理 |
| `--scope all`（既定） | 通常更新 | 全スコープを処理 |

## 重要原則

| 原則 | 内容 |
|-----|------|
| **固定順序** | マーケットプレイス → User → Project → Local の順序を厳守。順序を入れ替えない |
| **スコープ個別更新** | 同一プラグインが複数スコープにある場合、各スコープで個別に更新処理を行う（重複排除しない） |
| **継続実行** | 個別更新でエラーが発生しても処理を **中断せず** 次の対象へ進む。エラーは記録し最後に集計する |
| **失敗対応の確認** | 全フェーズ完了後、失敗があれば結果報告に続けてユーザにリトライ・スキップの対応を確認する |

## 実行フロー

### Phase A: 対象収集（読み取りのみ）

| 項目 | 取得元 |
|-----|-------|
| マーケットプレイス一覧 | `~/.claude/plugins/known_marketplaces.json` |
| User プラグイン | `~/.claude/settings.json` の `enabledPlugins` |
| Project プラグイン | `<repo>/.claude/settings.json` の `enabledPlugins` |
| Local プラグイン | `<repo>/.claude/settings.local.json` の `enabledPlugins` |

`<repo>` は現在のワーキングディレクトリ配下にある最も近い `.git` を持つディレクトリ。
git リポジトリ外で実行された場合は Project / Local をスキップ。

各プラグインエントリは **(scope, plugin-name, marketplace-name)** の 3 つ組として記録し、
スコープが異なれば同一 (plugin-name, marketplace-name) でも別エントリとして扱う。

### Phase B: マーケットプレイス更新（最初に必ず実行）

各マーケットプレイスに対して以下を順次実行する。

#### B-1. Git ソース（`source.source` が `github` または `git`）

```bash
INSTALL_LOC="<installLocation>"

# 事前確認: 手動編集形跡があれば破壊的操作を回避
cd "$INSTALL_LOC"
if [ -n "$(git status --porcelain)" ]; then
  echo "SKIP: $INSTALL_LOC has uncommitted changes"
  # スキップして次へ
fi

# 更新
git fetch --quiet origin
git reset --hard origin/HEAD 2>/dev/null || git pull --ff-only --quiet
```

#### B-2. ローカルパスソース（`source.source` が `path`）

更新不要。"Skipped (local path source)" として記録し次へ。

#### B-3. 失敗時

ネットワークエラー・認証エラー等は当該マーケットプレイスを失敗としてマーク。
**他のマーケットプレイス更新は継続**。

#### B-4. バージョン差分の記録

各プラグインの旧 / 新バージョンを Phase B-1 前後で
`<marketplace>/<plugin-source>/.claude-plugin/plugin.json` から読み取り、後の報告用に保持する。

### Phase C: User スコープのプラグイン更新

`--scope` が `user` または `all`（既定）の場合のみ実行。

User スコープの (plugin-name, marketplace-name) ごとに以下を実行する:

| ステップ | 内容 |
|---------|------|
| C-1 | 更新後マーケットプレイスにプラグインが存在することを確認 |
| C-2 | 旧バージョン → 新バージョンを比較し差分を記録 |
| C-3 | バージョン変動があれば「Updated」、同一なら「No change」、不在なら「Missing」 |
| C-4 | 例外発生時は「Failed」+ エラー内容を記録し次へ |

**同一プラグインが他スコープにも存在しても、ここでは User スコープエントリ全件を処理する**。

### Phase D: Project スコープのプラグイン更新

`--scope` が `project` または `all`（既定）かつ git リポジトリ配下の場合のみ実行。
処理内容は Phase C と同等（対象が Project スコープのエントリ）。

### Phase E: Local スコープのプラグイン更新

`--scope` が `local` または `all`（既定）かつ git リポジトリ配下の場合のみ実行。
処理内容は Phase C と同等（対象が Local スコープのエントリ）。

### Phase F: 結果報告

すべての更新処理を完了した時点で、以下の構造で **必ず結果報告** を提示する。

#### F-1. サマリ

```markdown
## 更新結果サマリ

| 区分 | 成功 | 変更なし | スキップ | 失敗 |
|-----|-----|---------|---------|-----|
| マーケットプレイス | {count} | - | {count} | {count} |
| User プラグイン | {count} | {count} | {count} | {count} |
| Project プラグイン | {count} | {count} | {count} | {count} |
| Local プラグイン | {count} | {count} | {count} | {count} |
```

#### F-2. マーケットプレイス詳細

```markdown
### マーケットプレイス

| マーケットプレイス | ソース種別 | 旧 SHA | 新 SHA | 結果 | 備考 |
|-----------------|----------|-------|-------|-----|-----|
| {name} | github / git / path | {old} | {new} | OK / Skipped / Failed | {理由 or エラー} |
```

#### F-3. スコープ別詳細

```markdown
### User プラグイン

| プラグイン | マーケットプレイス | 旧バージョン | 新バージョン | 結果 | 備考 |
|----------|-----------------|-----------|-----------|-----|-----|
| {plugin} | {marketplace} | {old} | {new} | Updated / No change / Missing / Failed | {備考} |

### Project プラグイン
（User と同形式）

### Local プラグイン
（User と同形式）
```

#### F-4. 次のアクション提示

```markdown
### 次のアクション

- [ ] `/reload-plugins` を実行して更新をセッションへ反映する
- [ ] （失敗があれば）次のリトライ・スキップ確認に応答する
```

### Phase G: 失敗対応の確認（失敗ありの場合のみ）

Phase F の結果報告後、**失敗が 1 件以上ある場合** は `AskUserQuestion` で以下を確認する。

#### G-1. 全体方針の確認

```text
AskUserQuestion({
  questions: [{
    question: "{N} 件の更新失敗があります。どう対応しますか？",
    header: "更新失敗対応",
    options: [
      { label: "全件リトライ", description: "失敗した全エントリをもう一度更新する" },
      { label: "個別に判断", description: "失敗エントリごとにリトライ / スキップを選択" },
      { label: "全件スキップ", description: "失敗エントリは諦めて完了する" }
    ],
    multiSelect: false
  }]
})
```

#### G-2. 個別判断モードの場合

各失敗エントリについて以下を確認:

```text
AskUserQuestion({
  questions: [{
    question: "[{scope}] {plugin}@{marketplace} の更新に失敗しました（理由: {error}）。リトライしますか？",
    header: "個別失敗対応",
    options: [
      { label: "リトライ", description: "もう一度更新を試行" },
      { label: "スキップ", description: "このエントリは諦める" }
    ],
    multiSelect: false
  }]
})
```

#### G-3. リトライ実行

リトライ対象エントリのみ Phase B-E と同等の処理を再実行する。
2 回目の失敗時は再度 Phase G を実行せず、最終結果として報告のみ行う。

## --dry-run モード時の挙動

`--dry-run` 指定時は **更新を一切実行せず**、以下のみ提示する:

- マーケットプレイス一覧と各 `autoUpdate` 設定値
- 各スコープの有効プラグイン一覧（重複も含めて全件）
- 「実行時に行われる更新内容」のプレビュー（Phase A-E の実行計画）
- Phase F / G はスキップ（失敗が発生しないため）

## 注意事項

- Git クローンに `git reset --hard` を実行するため、ユーザが該当ディレクトリで
  手動編集を行っている場合は更新をスキップする（破壊的操作の防止）。
- スコープ別更新で同一プラグインを複数回処理しても、マーケットプレイス側のファイルは
  既に最新化されているため副作用はない（冪等）。報告では各スコープに対し独立した行を出力する。
- `autoUpdate: true` 設定済みマーケットプレイスはセッション起動時にも自動更新される。
  本コマンドは **任意タイミングでの手動更新** を提供する。
- リトライ後も失敗が解消しない場合、ネットワーク・認証・対象ファイルの状態を個別に
  調査する必要がある。本コマンドは 2 回までの試行に留める（無限ループ防止）。

## 関連

- グローバルルール `~/.claude/rules/claude/plugin-auto-update.md`（自動更新ポリシー）
- `extension-toolkit:marketplace-toolkit`（マーケットプレイス本体管理）
- `extension-toolkit:marketplace-publisher`（マーケットプレイスへの公開）
