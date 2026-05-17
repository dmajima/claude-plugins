---
name: cleanup-workspace
description: Claude Code の `.claude/.local/work/` 配下の古いセッションフォルダ・一時ファイルを安全に削除するスキル。「古い作業フォルダを整理して」「セッションフォルダのクリーンアップ」「workspace を掃除」等の依頼で起動する。Use when cleaning up old session folders in `.claude/.local/work/`. SKIP when target is plugin updates (use plugins-update) or settings sync (use sync-settings).
---

# Cleanup Workspace

Claude Code のセッション作業領域 `.claude/.local/work/` に蓄積した古いセッションフォルダ・一時ファイルを安全に削除するスキル。グローバル（`~/.claude/.local/work/`）と現在のリポジトリ配下の双方を対象に、ドライラン + `AskUserQuestion` による削除前確認・パスバリデーションによる多重安全装置を備える。

## 責務

- `.claude/.local/work/` 配下のセッションフォルダ（`yyyyMMdd_nn_*` 形式）の列挙と古さ判定
- ドライラン（削除候補一覧と解放予定容量の表示のみ）
- 削除前確認（`AskUserQuestion` による最終承認）
- セッションフォルダ単位の安全削除
- `--include-tmp` 指定時の `workspace/tmp/` 配下のみの追加クリーンアップ
- 削除サマリ（成功 / 失敗 / 解放容量）の出力

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| プラグイン本体・マーケットプレイス更新 | `plugins-update` |
| Claude Code 設定（`~/.claude/`）の同期 | `sync-settings`（本プラグイン内） |
| ソースコード・git の clean | （対象外） |
| Playwright MCP 等のプラグイン専用キャッシュ削除 | （対象外、各プラグイン側で対応） |

## トリガー条件

- 「古い作業フォルダを整理して」
- 「セッションフォルダのクリーンアップ」
- 「`.claude/.local/work/` を掃除」
- 「workspace のメンテナンス」
- 「古い tmp ファイルを削除」

このスキルを起動しないケース:

- プラグイン本体の更新（→ `plugins-update`）
- Claude Code 設定の同期（→ `sync-settings`）
- ソースコード・git 作業ツリーの整理（→ 対象外）

## 前提

1. PowerShell 7+ が利用可能（Windows 主軸）
2. 削除対象パスが `.claude/.local/work/` 直下の `yyyyMMdd_nn_*` 形式
3. 削除実行は `AskUserQuestion` による明示承認後、または `--yes` フラグ指定時のみ

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` または `--yes` | 非対話 | 引数値で確定、`AskUserQuestion` をスキップして実行 |
| `--dry-run`（既定推奨） | ドライラン | 削除候補表示のみ、実削除なし |
| 上記以外 | 対話 | 候補表示後 `AskUserQuestion` で削除前確認 |

## 実行フロー

### 1. 引数解析

引数省略時の既定値は `~/.claude/.local/plugins/maintenance/cleanup-config.json`（グローバル配下）から読み込まれる。設定ファイル不在時は内蔵デフォルト（下表「初期値」）を採用。設定変更には `/cleanup-config` コマンドを使用する。

| 引数 | 初期値 | 説明 |
|-----|------|------|
| `--days N` | 30 | クリーンアップ閾値日数（atime ベース比較） |
| `--scope <global\|project\|both>` | both | 対象スコープ |
| `--dry-run` | false | ドライラン（実削除なし） |
| `--keep-recent N` | 0 | 最新 N 件のセッションを古さ条件に関係なく保持 |
| `--include-tmp` | false | `workspace/tmp/` 配下のみを別途追加削除 |
| `--yes` / `--non-interactive` | false | `AskUserQuestion` をスキップ |

### 2. 対象収集

詳細手順は [references/procedures.md](references/procedures.md) 節 1 を参照。

- グローバル: `~/.claude/.local/work/*/`
- プロジェクト: 現在のリポジトリルート（`git rev-parse --show-toplevel`）の `.claude/.local/work/*/`
- 同一パスの重複は除去

### 3. atime 戦略・古さ判定・keep-recent 適用

- **atime（最終アクセス日時）の解決**: 各セッションフォルダの `progress.md` の `LastWriteTimeUtc` を「最終アクセス日時」として採用する。`progress.md` が存在しないセッションは **フォールバック**（セッションフォルダ自身 + 配下最大 mtime）で代用する
- 解決された atime が `--days` 閾値より古いものを候補に追加
- `--keep-recent N` 指定時はスコープごとに新しい順 N 件を候補から除外

### 4. バリデーション（必須・省略不可）

詳細は [references/safety.md](references/safety.md) を参照。

- パスが `.claude/.local/work/` 配下の `yyyyMMdd_nn_*` 形式であることを正規表現照合
- 親ディレクトリ（`work/` 自体・`.claude/.local/` 自体）は絶対に対象外
- シンボリックリンクは追従しない（リンク自体も削除対象外）
- 進行中セッション（`progress.md` mtime が `active_session_minutes` 分以内、初期値 5 分）は保護

### 5. ドライラン or 削除前確認

| モード | 動作 |
|-----|------|
| `--dry-run` | 候補一覧 + 合計容量を表示して終了 |
| 対話モード | 候補表示後、`AskUserQuestion` で「削除する / ドライランで終了 / キャンセル」を確認 |
| `--yes` | 候補表示後、確認なしで即削除 |

`AskUserQuestion` の選択肢構造は [references/procedures.md](references/procedures.md) 節 3 を参照。

### 6. 削除実行

- バリデーション合格分のみ `Remove-Item -Recurse -Force` で削除
- 失敗時は当該セッションフォルダのみスキップし、他は続行
- 失敗一覧をサマリに含める

### 7. `--include-tmp` の追加クリーンアップ

`--include-tmp` 指定時のみ、削除対象外のセッションフォルダについても `workspace/tmp/` 配下のファイルを掃除する（セッションフォルダ自体は保持）。

### 8. サマリ出力

| 項目 | 内容 |
|-----|------|
| 削除完了数 | N 件 |
| 削除失敗数 | N 件（失敗理由付き） |
| 解放容量 | XXX MB |
| 保護されたセッション | N 件（keep-recent / 進行中） |

### 9. 検証

- [ ] バリデーション失敗時は当該パスを削除しない
- [ ] `work/` 自体・`.claude/.local/` 自体は削除されていない
- [ ] シンボリックリンクが追従されていない（リンク自体も削除されていない）
- [ ] 進行中セッションが保護されている
- [ ] サマリが正しく出力される
- [ ] `--dry-run` 指定時は実削除が行われていない

### 10. 引き渡し

削除サマリをユーザに提示。失敗があれば失敗理由を併記し、必要に応じてユーザの個別判断を仰ぐ。

## 重要な制約

- 削除対象は `.claude/.local/work/{yyyyMMdd_nn_*}/` 形式のセッションフォルダのみ（バリデーション必須）
- `--yes` / `--non-interactive` 指定でもバリデーションは省略不可
- 親ディレクトリ（`work/`・`.claude/.local/`・`.claude/`）の削除は禁止
- シンボリックリンクの追従禁止（リンク自体の削除も対象外）
- 進行中セッションの削除は禁止（`progress.md` の最新更新が `active_session_minutes` 分以内、初期値 5 分なら保護）
- 「最終アクセス日時」の解決は `progress.md` mtime → 配下最大 mtime（フォールバック）の順で行う（NTFS atime が Windows 既定で無効化されているため、Claude Code セッション運用に整合する戦略を採用）
- パス記法はポータブルに保つ（ローカル絶対パスのハードコード禁止）
- 既存ファイル更新時のエンコーディング・改行コードを維持する（`~/.claude/rules/common/file-encoding.md` 参照）
- ユーザに選択を求める場合は `AskUserQuestion` を使用する
- `git commit` 以降の操作は実行しない（ユーザ判断に委ねる）
- 作業完了報告前に自己検証（バリデーション / ドライラン挙動 / サマリ出力）を実施

## 参照

| 用途 | ファイル |
|-----|---------|
| 詳細実行手順 | [references/procedures.md](references/procedures.md) |
| 安全装置の詳細 | [references/safety.md](references/safety.md) |
| 実装スクリプト（cleanup 本体） | [`references/scripts/cleanup/cleanup.ps1`](references/scripts/cleanup/cleanup.ps1) |
| 実装スクリプト（設定操作） | [`references/scripts/cleanup/cleanup-config.ps1`](references/scripts/cleanup/cleanup-config.ps1) |
| 設定ファイル本体 | `~/.claude/.local/plugins/maintenance/cleanup-config.json`（グローバル配下に集約）|
| 設定変更コマンド | `/cleanup-config`（`commands/cleanup-config.md`）|
| セッションフォルダ規約（global rule） | `~/.claude/rules/claude/work-directory.md` |
| ローカルデータ領域規約（global rule） | `~/.claude/rules/claude/local-data-directory.md` |
| 動作例 | [evals/](evals/) |
