---
description: 全マーケットプレイス・プラグインを一括更新（User/Project/Local 全スコープ対応）
argument-hint: [--dry-run] [--scope user|project|local|all]
---

ユーザの引数: $ARGUMENTS

インストール済みマーケットプレイスとそこから導入されたプラグインを **一括で最新版に更新** するコマンド。
User / Project / Local の全スコープを対象にし、最後に `/reload-plugins` を実行してセッションへ反映する。

## 動作モード判定

| 引数 | モード | 動作 |
|-----|-------|------|
| 空 | 通常更新 | 全スコープのマーケットプレイス・プラグインを更新 |
| `--dry-run` 含む | 確認のみ | 更新対象一覧を表示。実際の更新は行わない |
| `--scope user` / `--scope project` / `--scope local` | スコープ限定 | 指定スコープのみ更新 |
| `--scope all`（既定） | 通常更新 | 全スコープを更新 |

## 実行フロー

### 1. マーケットプレイス一覧の収集

`~/.claude/plugins/known_marketplaces.json` を Read で読み込み、登録済みマーケットプレイスの
`name` / `source` / `installLocation` / `autoUpdate` を取得する。

### 2. スコープ別有効プラグインの収集

以下の設定ファイルをそれぞれ Read し、`enabledPlugins` フィールドから有効化されている
プラグイン名とマーケットプレイス名のペアを抽出する。設定ファイル不在のスコープはスキップする。

| スコープ | 設定ファイル |
|---------|------------|
| User | `~/.claude/settings.json` |
| Project | `<repo>/.claude/settings.json` |
| Local | `<repo>/.claude/settings.local.json` |

`<repo>` は現在のワーキングディレクトリ配下にある最も近い `.git` を持つディレクトリ。
Project / Local 設定ファイルは git リポジトリ外で実行された場合スキップする。

### 3. マーケットプレイスの更新

各マーケットプレイスに対して以下を実行する。

#### 3.1 Git ソース（`source.source` が `github` または `git`）の場合

`installLocation` で指定された複製先で更新を実行:

```bash
INSTALL_LOC="<installLocation>"
cd "$INSTALL_LOC" && git fetch --quiet origin && \
  git reset --hard origin/HEAD 2>/dev/null || \
  git pull --ff-only --quiet
```

`reset --hard` は破壊的な操作のため、`installLocation` 配下が
**Claude Code が管理するクローン** であることを必ず事前確認する。
ユーザが手動編集した形跡（`git status` がクリーンでない）がある場合は、
更新をスキップしてユーザに通知する。

#### 3.2 ローカルパスソース（`source.source` が `path`）の場合

参照元が直接ローカルディレクトリのため更新不要。スキップしてログに「local path source, skipped」と記録する。

#### 3.3 失敗時

ネットワークエラー・認証エラー等で失敗した場合は、当該マーケットプレイスを失敗としてマークし、
他のマーケットプレイス更新は **継続** する（fail-fast にしない）。

### 4. プラグインの更新確認

マーケットプレイスを更新したことで配下のプラグインファイル実体は最新化されている。
追加の `/plugin update` 実行は不要だが、`enabledPlugins` に列挙されたプラグインが
更新後のマーケットプレイスに依然として存在することを確認する。

存在しなくなったプラグイン（マーケットプレイス側から削除された等）はユーザに警告する。

### 5. リロード実行

最後に `/reload-plugins` を Claude Code 上で実行し、更新内容をセッションに反映する。
コマンドの最後で利用者にリロード実行を促すメッセージを提示する。

### 6. 結果報告

以下の形式で結果を提示する:

```markdown
## 更新結果

### マーケットプレイス

| マーケットプレイス | ソース種別 | 結果 | 備考 |
|-----------------|----------|-----|------|
| {name} | github / git / path | OK / Skipped / Failed | {理由} |

### スコープ別プラグイン

| スコープ | プラグイン | マーケットプレイス | 結果 |
|---------|----------|-----------------|-----|
| User | {plugin} | {marketplace} | OK / Missing |
| Project | ... | ... | ... |
| Local | ... | ... | ... |

### 次のアクション

- [ ] `/reload-plugins` を実行して更新をセッションへ反映する
- [ ] 失敗したマーケットプレイスがあればネットワーク・認証を確認する
```

## --dry-run モード時の挙動

`--dry-run` 指定時は **更新を一切実行せず**、以下のみ提示する:

- マーケットプレイス一覧と各々の `autoUpdate` 設定値
- スコープ別の有効プラグイン一覧
- 「実行時に行われる更新内容」のプレビュー

## 注意事項

- `known_marketplaces.json` の `autoUpdate: true` が設定されているマーケットプレイスは
  Claude Code セッション起動時にも自動更新される。本コマンドはそれに加えて **任意のタイミングでの手動更新** を提供する。
- Git クローンに `git reset --hard` を実行するため、ユーザが該当ディレクトリで
  手動編集を行っている場合は更新をスキップする（破壊的操作の防止）。
- 認証情報が必要なプライベートリポジトリのマーケットプレイスは、
  Git の credential helper / SSH キーが設定されている前提で動作する。

## 関連

- グローバルルール `~/.claude/rules/claude/plugin-auto-update.md`（自動更新ポリシー）
- `extension-toolkit:marketplace-toolkit`（マーケットプレイス本体管理）
- `extension-toolkit:marketplace-publisher`（マーケットプレイスへの公開）
