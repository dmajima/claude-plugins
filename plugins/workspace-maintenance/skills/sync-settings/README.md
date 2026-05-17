# sync-settings (skill)

特定の Git リポジトリから Claude Code のユーザ設定（`~/.claude/settings.json` / `~/.claude/skills/` / `~/.claude/rules/` / `~/.claude/agents/` 等）を **pull 方向のみ** で同期するスキル。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は `SKILL.md` および `references/` 配下を参照してください。

## 責務（要約）

- Git リポジトリから Claude Code ユーザ設定を取得して `~/.claude/` に適用
- ドライラン + バックアップ + AskUserQuestion による多層安全装置
- 戦略選択（overwrite / merge / skip）
- 設定の永続化（次回実行時の既定値）

## 導入手順

### 前提

- Claude Code がインストール済み
- `workspace-maintenance` プラグインがインストール済み
- Git CLI 2.30+ が利用可能
- PowerShell 7+ が利用可能（Windows 主軸）
- 同期元リポジトリへのアクセス権限（プライベートの場合は認証設定済み）

### 起動方法

以下のフレーズで自動起動します:

- 「Claude の設定を Git から同期して」
- 「`~/.claude/` を Git リポジトリから更新」
- 「`settings.json` をリモート repo から取得」
- 「skills / rules を別マシンと同期」

## 利用方法（最小例）

### 例 1: 初回・対話モードで設定収集

ユーザ:
> Claude の設定を https://github.com/myaccount/claude-settings から同期して

Claude（要約）:
> URL を sync-config.json に記録。一時ディレクトリに clone し、差分を表示。AskUserQuestion で「同期する / ドライランで終了 / キャンセル」を確認。「同期する」選択時はバックアップ取得後に同期実行。

### 例 2: ドライランで差分確認

ユーザ:
> 設定の同期差分を dry-run で確認して

Claude（要約）:
> 前回の repo / branch を再利用し、差分を表示。実適用は行わない。

### 例 3: 戦略変更

ユーザ:
> マージ戦略で同期して（既存設定を保持しつつ追加分のみ取り込む）

Claude（要約）:
> `--strategy merge` 相当で同期。settings.json は JSON マージ、ディレクトリは結合。

## トリガー例

| 発話 | 既定動作 |
|-----|---------|
| 「Claude の設定を Git から同期して」 | 対話モード + 既定戦略（overwrite） |
| 「dry-run で見せて」 | `--dry-run` 相当 |
| 「マージで同期して」 | `--strategy merge` 相当 |
| 「skip 戦略で同期して」 | `--strategy skip` 相当（既存保持・新規のみ追加） |

## 安全装置

| 装置 | 内容 |
|-----|------|
| バックアップ | 既定で必須。同期前に `~/.claude/.local/plugins/workspace-maintenance/backup/YYYYMMDD_HHmmss/` に取得 |
| ドライラン推奨 | 既定動作は差分表示のみ。実適用には明示承認が必要 |
| AskUserQuestion による最終確認 | 対話モードでは同期前に必ず確認 |
| 認証情報の除外 | `credentials.json` / `.env` 等は同期対象から自動除外 |
| Git メタデータの除外 | `.git/` 等は同期対象外 |
| pull 方向のみ | リモートへの push は行わない |

## ロールバック手順

同期後に問題が発生した場合:

1. バックアップディレクトリ（`~/.claude/.local/plugins/workspace-maintenance/backup/YYYYMMDD_HHmmss/`）を確認
2. 該当ファイル・ディレクトリを `~/.claude/` に戻す（手動コピー）
3. または OS の復元機能（Windows ファイル履歴、Time Machine 等）を利用

自動ロールバックコマンドは提供しません（誤操作防止のため）。

## 関連スキル

| スキル | 関係 |
|-------|------|
| `cleanup-workspace`（本プラグイン内） | 作業フォルダ整理。同期とは別関心 |
| `plugins-update` | プラグイン更新。本スキルは設定のみ対象 |
| `credentials-manager` | 認証情報管理。プライベート repo 利用時に連携 |

## 主要参照ファイル

| ファイル | 内容 |
|---------|------|
| `SKILL.md` | スキル定義とトリガー条件 |
| `references/procedures.md` | 詳細実行手順 |
| `references/safety.md` | 安全装置の詳細 |
| `references/strategies.md` | 戦略別の動作詳細 |
| `references/scripts/sync/sync.ps1` | 実装スクリプト（PowerShell） |
| `evals/` | 動作分岐の期待挙動 |
