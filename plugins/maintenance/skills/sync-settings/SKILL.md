---
name: sync-settings
description: Git リポジトリから Claude Code 設定（`settings.json` / `skills/` / `rules/` 等）を `~/.claude/` に pull 同期するスキル。「Claude 設定を Git から同期」「~/.claude を Git から更新」等で起動。Use when syncing Claude settings from a Git repo. SKIP when target is workspace cleanup (use cleanup-workspace) or plugin updates (use plugins-update).
---

# Sync Settings

特定の Git リポジトリと Claude Code のユーザ設定（`~/.claude/settings.json` / `~/.claude/skills/` / `~/.claude/rules/` / `~/.claude/agents/` 等）を **pull / push 双方向** で同期するスキル。pull は `/sync-pull`（既存）/ push は `/sync-push`（Phase 3-D 追加）で操作。Git による履歴管理を前提に、ドライラン + バックアップ + `AskUserQuestion` 確認の多層安全装置を備える。

## 責務

- 指定 Git リポジトリの `clone` または既存複製の `fetch` + `pull`（リモートのみ取得）
- 同期対象（`settings.json` / `skills/` / `rules/` / `agents/` / `hooks/` / `CLAUDE.md` 等）の差分検出
- ドライラン（変更プレビューのみ・実適用なし）
- 同期前の `~/.claude/` バックアップ取得（既定: 必須）
- 戦略別の同期適用（overwrite / merge / skip）
- 設定状態の永続化（最後の repo / branch / targets / strategy）

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| 古いセッションフォルダ・一時ファイル削除 | `cleanup-workspace`（本プラグイン内） |
| プラグイン本体・マーケットプレイス更新 | `plugins-update` |
| ローカルから Git リポジトリへの push 同期 | （対象外、利用者が手動で実施） |
| 認証情報の取り扱い | `credentials-manager`（既存プラグイン） |

## トリガー条件

- 「Claude の設定を Git から同期して」
- 「`~/.claude/` を Git リポジトリから更新」
- 「`settings.json` をリモート repo から取得」
- 「skills / rules を別マシンと同期」

このスキルを起動しないケース:

- 作業フォルダ整理（→ `cleanup-workspace`）
- プラグイン本体の更新（→ `plugins-update`）
- ローカル → リモートへの push（→ 対象外）

## 前提

1. Git CLI 2.30+ が利用可能
2. 同期元リポジトリの URL（または `sync-config.json` から取得）
3. 同期元リポジトリの想定構造: トップレベルに `settings.json` / `skills/` / `rules/` 等を含む（または `claude/` サブディレクトリ配下）
4. プライベートリポジトリの場合は認証情報の設定済み（`credentials-manager` 連携推奨）

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` または `--yes` | 非対話 | 引数値・設定ファイル値で確定、`AskUserQuestion` をスキップ |
| `--dry-run`（既定推奨） | ドライラン | 差分表示のみ、実適用なし |
| 上記以外 | 対話 | 不足パラメータと最終確認を `AskUserQuestion` で確認 |

## 実行フロー

### 1. 設定解決

詳細は [references/procedures.md](references/procedures.md) 節 1 を参照。

| 取得元 | パス |
|-------|-----|
| 設定ファイル | `~/.claude/.local/plugins/maintenance/sync-config.json` |
| 引数オーバーライド | `--repo` / `--branch` / `--targets` / `--strategy` |

設定ファイル不在 + 引数不足の場合は対話で収集。

### 2. リポジトリ取得

| 状態 | 動作 |
|-----|------|
| 初回 | 一時ディレクトリ（`~/.claude/.local/plugins/maintenance/repo/`）に `clone` |
| 2 回目以降 | 既存複製で `fetch` + `reset --hard origin/<branch>` |

クローン先は固定パスで再利用し、毎回 fresh checkout する（ローカル変更の混入を防ぐ）。

### 3. 同期対象の収集

`--targets` で指定された対象を、クローン先内で実在チェックする。既定対象:

| 対象 | パス（クローン先） |
|-----|--------|
| `settings.json` | クローン先 `/settings.json` または `/claude/settings.json` |
| `skills/` | クローン先 `/skills/` または `/claude/skills/` |
| `rules/` | クローン先 `/rules/` または `/claude/rules/` |
| `agents/` | クローン先 `/agents/` または `/claude/agents/` |
| `hooks/` | クローン先 `/hooks/` または `/claude/hooks/` |
| `CLAUDE.md` | クローン先 `/CLAUDE.md` または `/claude/CLAUDE.md` |

### 4. 差分検出

各対象について `~/.claude/` 側との差分を検出する。詳細は [references/procedures.md](references/procedures.md) 節 2 を参照。

| 差分種別 | 表示 |
|---------|-----|
| 新規（リモートのみ） | `[ADD]` |
| 削除（ローカルのみ） | `[DEL]`（既定では適用しない、`--prune` 指定時のみ） |
| 変更（差分あり） | `[MOD]` |
| 一致 | `[OK]`（表示省略） |

### 5. ドライラン or 確認

| モード | 動作 |
|-----|------|
| `--dry-run` | 差分一覧 + 合計件数を表示して終了 |
| 対話モード | 差分表示後、`AskUserQuestion` で「同期する / ドライランで終了 / キャンセル」を確認 |
| `--yes` | 差分表示後、確認なしで即同期 |

### 6. バックアップ取得

`--no-backup` が指定されていなければ、同期対象を `~/.claude/.local/plugins/maintenance/backup/YYYYMMDD_HHmmss/` にコピーする。詳細は [references/procedures.md](references/procedures.md) 節 3 を参照。

### 7. 戦略別の同期適用

| 戦略 | 動作 |
|-----|------|
| `overwrite`（既定） | 既存ファイルを上書き、新規ファイルは追加 |
| `merge` | `settings.json` は JSON マージ、ディレクトリは結合（既存個別ファイルを保持） |
| `skip` | 既存ファイルは保持、新規ファイルのみ追加 |

詳細は [references/procedures.md](references/procedures.md) 節 4 を参照。

### 8. 設定状態の永続化

成功時、`sync-config.json` に最後の `repo` / `branch` / `targets` / `strategy` / `last_sync_at` を記録する。

### 9. 検証

- [ ] バックアップが取得されている（`--no-backup` 未指定時）
- [ ] バックアップディレクトリのタイムスタンプが今回のセッションと一致
- [ ] `~/.claude/` 配下が同期戦略どおりに更新されている
- [ ] `sync-config.json` が更新されている
- [ ] パスポータビリティ合格

### 10. 引き渡し

同期サマリ + バックアップパス + ロールバック手順をユーザに提示する。

## 重要な制約

- pull / push 双方向対応（pull は `sync.ps1` / push は `sync-push.ps1`、マッピング設定 `sync-mappings.json` を共有）
- バックアップは既定で必須。`--no-backup` 指定時はその旨を明示警告
- `~/.claude/.git` 等の Git メタデータは同期対象外（リモートに含まれる場合も除外）
- 認証情報（`credentials.json` / `.env` / `*.pem` / `*.key` 等）は同期対象から自動除外（大小文字非感応・正規化済み判定）
- Repo URL は `https://` / `http://` / `git://` / `ssh://` / `git@host:` のみ許可（引数インジェクション対策）
- Branch 名は `[A-Za-z0-9._/\-]+` のみ許可
- 同期前バリデーション: 同期元リポジトリのトップレベル構造を確認し、想定外（任意のファイルが大量等）なら警告
- `--yes` / `--non-interactive` 指定でもバックアップは省略不可
- パス記法はポータブルに保つ（ローカル絶対パスのハードコード禁止）
- 既存ファイル更新時のエンコーディング・改行コードを維持する（`~/.claude/rules/common/file-encoding.md` 参照）
- ユーザに選択を求める場合は `AskUserQuestion` を使用する
- `git commit` 以降の操作は実行しない（ユーザ判断に委ねる）
- 作業完了報告前に自己検証（バックアップ取得 / 認証情報除外 / 設定永続化）を実施

## 参照

| 用途 | ファイル |
|-----|---------|
| 詳細実行手順 | [references/procedures.md](references/procedures.md) |
| 安全装置 | [references/safety.md](references/safety.md) |
| 同期戦略 | [references/strategies.md](references/strategies.md) |
| 実装スクリプト（pull 同期本体） | [`references/scripts/sync/sync.ps1`](references/scripts/sync/sync.ps1) |
| 実装スクリプト（push 同期） | [`references/scripts/sync/sync-push.ps1`](references/scripts/sync/sync-push.ps1) |
| 実装スクリプト（マッピングストア CRUD） | [`references/scripts/sync/sync-mappings.ps1`](references/scripts/sync/sync-mappings.ps1) |
| マッピング設定ファイル | `~/.claude/.local/plugins/maintenance/sync-mappings.json`（グローバル配下に集約。global + projects[<absolute_path>] のスコープ別マッピング）|
| コマンド（pull） | `/sync-pull`（`commands/sync-pull.md`）|
| コマンド（push） | `/sync-push`（`commands/sync-push.md`）|
| コマンド（マッピング設定）| `/sync-map-set` / `/sync-map-list` / `/sync-map-delete` |
| 認証情報管理（関連プラグイン） | `credentials-manager`（プライベート repo 同期時に推奨） |
| 動作例 | [evals/](evals/) |
