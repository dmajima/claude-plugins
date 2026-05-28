# 安全装置の詳細

`sync-settings` スキルの多層安全装置の設計と運用ルール。

## 1. 安全装置の階層

| 階層 | 装置 | 防止する事故 |
|-----|------|-----------|
| 1 | バックアップ取得（既定必須） | 同期後に問題が判明した場合の復旧手段確保 |
| 2 | 認証情報の自動除外 | `credentials.json` / `.env` 等の上書きによる認証情報破壊 |
| 3 | Git メタデータの除外 | `.git/` ディレクトリの混入による既存リポジトリ破壊 |
| 4 | 同期対象のホワイトリスト | 任意ファイルの無差別同期防止 |
| 5 | ドライラン推奨 | 想定外の同期（事前確認なし） |
| 6 | AskUserQuestion 確認 | 同期直前の最終承認 |
| 7 | push 時は新ブランチ + PR 強制 | 規定ブランチへの直接 push 防止・レビュー前提のワークフロー |

## 2. バックアップ取得（既定必須）

### 2.1 取得条件

- `--no-backup` フラグが指定されていない場合、必ずバックアップを取得
- 取得失敗時はエラーで終了し、同期は実行しない（安全側）
- `--yes` / `--non-interactive` でもバックアップは省略不可

### 2.2 取得パス

```
~/.claude/.local/plugins/maintenance/backup/{YYYYMMDD_HHmmss}/
```

タイムスタンプは UTC ベース。同一秒に複数実行された場合は連番（`_2`、`_3`）を付与。

### 2.3 保持ポリシー

- バックアップは自動削除しない（ユーザの明示削除に委ねる）
- 容量逼迫時は `cleanup-workspace` スキルでは対象外（`.local/plugins/maintenance/backup/` は別管理）
- 必要に応じてユーザが手動削除

### 2.4 ロールバック手順

1. 該当バックアップディレクトリを特定（`backup/YYYYMMDD_HHmmss/`）
2. ファイル・ディレクトリを `~/.claude/` に戻す（手動コピー）
3. または OS の復元機能（Windows ファイル履歴、Time Machine 等）を併用

自動ロールバックコマンドは提供しない（誤操作防止のため、ユーザの明示判断を要求）。

## 3. 認証情報の自動除外

### 3.1 除外パスのリスト

同期対象から **常に除外** されるパス:

| パス | 理由 |
|-----|------|
| `~/.claude/credentials.json` | 認証情報（`credentials-manager` プラグイン管理下） |
| `~/.claude/.env` `~/.claude/.env.*` | 環境変数ファイル |
| `~/.claude/.local/` | ローカルデータ領域（再帰回避を含む） |
| `~/.claude/.git/` | Git メタデータ |
| `~/.claude/plugins/cache/` | プラグインキャッシュ |
| `*.pem` `*.key` 等の秘密鍵ファイル | 認証情報 |

### 3.2 リモート側に存在しても適用しない

リモート repo にうっかり認証情報がコミットされていた場合でも、本スキルは適用しない。差分一覧には警告として表示する。

## 4. Git メタデータの除外

### 4.1 除外パス

| パス | 理由 |
|-----|------|
| `<remote>/.git/` | リモート repo の Git メタデータ |
| `<remote>/.gitignore` | リモートの gitignore（同期するとローカル設定上書きの可能性） |
| `<remote>/.gitmodules` | サブモジュール定義 |

### 4.2 ローカルの `~/.claude/.git/`

仮にユーザが `~/.claude/` 自体を git 管理している場合でも、本スキルは `.git/` 配下を操作しない。同期は通常のファイル・ディレクトリ操作のみで完結する。

## 5. 同期対象のホワイトリスト

### 5.1 既定対象

| 対象 | 種別 |
|-----|------|
| `settings.json` | ファイル |
| `skills/` | ディレクトリ |
| `rules/` | ディレクトリ |
| `agents/` | ディレクトリ |
| `hooks/` | ディレクトリ |
| `CLAUDE.md` | ファイル |

### 5.2 ユーザ拡張

`--targets` 引数または `sync-config.json` で対象を変更可能。ただし以下は常に除外（節 3.1 参照）。

| 拒否対象 | 理由 |
|---------|------|
| `credentials.json` | 認証情報 |
| `.env*` | 環境変数 |
| `.local/` | ローカルデータ |
| `.git/` | Git メタデータ |
| `plugins/cache/` | プラグインキャッシュ |

ユーザが `--targets credentials.json` を指定してもスクリプトは拒否する。

## 6. ドライラン推奨

### 6.1 既定動作

`--dry-run` を明示しない場合、対話モードでは `AskUserQuestion` が必ず発火するため、事実上のドライラン体験を提供する。

### 6.2 非対話モードでの安全装置

`--yes` / `--non-interactive` 指定時は `AskUserQuestion` がスキップされるが:

- バックアップは省略不可
- 認証情報の自動除外は省略不可
- Git メタデータの除外は省略不可
- `--dry-run` と `--yes` を同時指定した場合は `--dry-run` 優先

## 7. AskUserQuestion 確認

### 7.1 確認タイミング

- 同期対象収集後・バックアップ取得前
- 差分件数が 0 件の場合はスキップ（同期不要）
- 差分件数が大量（例: 100 件超）の場合は追加の確認を要求

### 7.2 `--prune` の追加確認

`--prune` 指定 + 削除対象が 10 件超の場合、`AskUserQuestion` で追加確認:

```text
"削除対象が {N} 件あります。本当に削除しますか？"
```

## 8. push 方向の安全装置（Phase 3-D 以降）

`/sync-push` コマンド経由の push 同期では、以下の安全装置を **強制** する。

### 8.1 規定ブランチへの直接 push 禁止

`sync-push.sh` は常に新ブランチ `{BranchPrefix}-{scope}-{timestamp}` を作成して
そこに push し、PR ベースのレビュー → マージワークフローに乗せる。マッピングの
`remote_branch`（既定 `main`）に対して直接 push することは設計上禁止である。

### 8.2 push 用 clone 領域の分離

push 用には専用ディレクトリ `~/.claude/.local/plugins/maintenance/repo-push/` を
利用する（pull 用は `repo/`）。これにより pull と push の同時実行・連続実行で
互いの git 状態を壊さない。

### 8.3 push 前後のブランチ復帰

push 完了後は規定ブランチ（`remote_branch`）に自動復帰し、スキル起動前と
同様の clone 領域状態に戻す。復帰失敗時は warning を表示し、手動 checkout
を案内する。

### 8.4 認証情報の二重除外（pull と同等以上の厳格性）

push 経路でも `Test-FileExcluded` は同一の除外リスト（`credentials.json`
/ `.env` / `.netrc` / `.git-credentials` / `id_rsa*` 等の SSH 秘密鍵 /
`*.p12` / `*.crt` / `*.gpg` / クラウド認証ファイル / `.ssh` / `.gnupg`
/ `.aws` 配下など）を適用する。push 完了前にローカル → repo-push/
コピー段階で漏れなくフィルタする。

### 8.5 マッピング由来値の再検証

`sync-mappings.json` 由来の `remote_repo` / `remote_branch` を毎回
正規表現で再検証する。外部書き換えや別経路での注入を防御する。

### 8.6 PR 作成の明示

`gh pr create --repo <repo> --base <branch> --head <new-branch>` 形式で
リポジトリを明示し、誤った別リポジトリへの PR 投稿を防ぐ。gh CLI 不在時は
手動 PR 作成案内のみで終了する。

### 8.7 ローカル clone 領域への書き込み（pull 共通）

`~/.claude/.local/plugins/maintenance/repo/`（pull 用）および
`~/.claude/.local/plugins/maintenance/repo-push/`（push 用）配下では
`git reset --hard` + `git clean -fdx` を実行するが、これらはローカル
クローンの初期化のみであり、規定ブランチには直接 push されない（8.1）。

## 9. settings.json マージ時の危険キー温存（任意コード実行リスク抑制）

`merge` 戦略で `settings.json` をマージする際、Claude Code が起動時に
shell コマンドや外部プロセスを起動する可能性のある **危険キー** は
ローカル優先で温存する。リモートが悪意ある hooks / mcpServers を含む
場合でも、既存ローカルの設定が温存されるため、任意コード実行リスクを
抑制できる。

### 9.1 温存対象キー（settings.json トップレベル）

| キー | 理由 |
|-----|------|
| `hooks` | PreToolUse / PostToolUse / 等のシェルコマンド実行 |
| `mcpServers` | 外部プロセス起動定義 |
| `env` | 環境変数経由のコマンド注入余地 |
| `permissions` | 権限制御の改変による横展開リスク |
| `extraKnownMarketplaces` | プラグインソース改ざんによる自動更新の誘導 |
| `apiKeyHelper` / `customApiKeyResponses` | 認証情報取得経路の差し替え |
| `awsAuthRefresh` / `awsCredentialExport` | AWS 認証フローの差し替え |
| `enabledPlugins` / `disabledPlugins` | 有効プラグインの操作 |

### 9.2 動作

- ローカルに該当キーが **存在する場合**: リモート値を **無視** してローカルを保持。
  warning メッセージで `[merge:safety] settings.json の '<key>' キーはローカルを保持します`
  を出力。
- ローカルに該当キーが **不在の場合**: リモート値を採用するが、`[merge:notice]`
  で「次回以降は明示確認の上で更新してください」と注意喚起。
- 配列・他のキーは通常通りリモート優先で上書きされる。

### 9.3 配列型キーの完全置換について

`Merge-JsonValue` は配列をローカル温存ではなく **リモート完全置換** で扱う仕様。
Claude Code の `settings.json` 標準スキーマでは `hooks` / `mcpServers` / `env` /
`permissions` はオブジェクト型のため、9.1 の温存判定（トップレベルでローカル優先）が
機能する。

仮にリモートが標準外で **トップレベルを配列型に偽装** したり、保護対象キー自体を
配列で配信した場合（例: `"hooks": [...]`）、`Merge-JsonValue` は **配列を検出した
時点で温存判定に到達する前にリモート全置換** する設計となっている。本ケースは標準
スキーマからの逸脱として `[merge:warning]` メッセージを出力するため、`--dry-run`
プレビュー段階で気付ける構造を残している。

### 9.4 Unicode 同形異字攻撃の遮断

`Merge-JsonValue` はキー名に非 ASCII 文字（キリル文字の 'е' でラテン文字の 'e' を
偽装する等）が含まれることを検出し、トップレベル（`IsRootSettings = $true`）では
**非 ASCII キーをローカル優先で温存** する。ローカルに同名キーがなければ
**リモート値を採用せず無視** する（攻撃想定）。`[merge:safety]` メッセージで通知する。

### 9.5 利用者への推奨

リモート repo の信頼性が低い場合は **`merge` 戦略を避け、`overwrite` 戦略 + `--dry-run`
プレビュー + 個別承認** を経由することを推奨する。`overwrite` 戦略でも、差分プレビュー段階で
危険キーの変更を視覚的に確認できる。

## 10. 検証チェックリスト

スキル実装の検証項目:

- [ ] `--no-backup` 未指定時にバックアップが取得されることをテスト（pull）
- [ ] `credentials.json` が同期対象から除外されることをテスト（pull / push）
- [ ] `.env` が同期対象から除外されることをテスト（pull / push）
- [ ] `id_rsa` 系 SSH 秘密鍵が同期対象から除外されることをテスト（pull / push）
- [ ] `.git/` が同期対象から除外されることをテスト（pull / push）
- [ ] `--dry-run` 指定時に実適用が行われないことをテスト
- [ ] `--yes` 指定時にバックアップが省略されないことをテスト（pull）
- [ ] バックアップ失敗時に同期が実行されないことをテスト（pull）
- [ ] push 時に規定ブランチに直接 commit/push されないことをテスト
- [ ] push 完了後に規定ブランチへ復帰することをテスト
- [ ] 認証情報の二次マスクが git/gh 出力に適用されることをテスト
- [ ] マッピング由来 remote_repo / remote_branch の再検証で不正値を弾くこと
- [ ] settings.json の `hooks` / `mcpServers` / `env` / `permissions` キーが
      merge 戦略でローカル優先温存されることをテスト（節 9）
- [ ] Get-NonReparseFileItems により symlink / junction が
      pull / push / バックアップ取得経路で追従されないことをテスト

これらは `evals/` 配下の各ケースで動作分岐として記述する。
