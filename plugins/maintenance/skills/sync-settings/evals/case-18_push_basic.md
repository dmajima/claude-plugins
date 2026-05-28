# Case 18: `/sync-push` 基本動作（新ブランチ + PR 作成）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "/sync-push --scope global --dry-run" or "/sync-push"（対話モード）|
| 引数 | `--scope global --dry-run`（非対話 dry-run）または引数なし（対話）|
| 既存状態 | global マッピング設定済 + リモートへ push 権限あり + gh CLI 認証済 + ローカル `~/.claude/` 配下に変更あり |

## 期待動作

### Phase 1: マッピング解決
- `sync-push.sh -Mapping global` で sync-mappings.json から repo/branch/targets を取得
- マッピング不在時はエラーで終了

### Phase 2: clone 領域の最新化
- `~/.claude/.local/plugins/maintenance/repo/` を fetch + checkout <branch> + reset --hard origin/<branch>
- 既存ローカル変更は破棄（fresh checkout）

### Phase 3: ローカル → repo/ コピー
- targets ごとに `~/.claude/<target>` から `repo/<target>` へ Copy-Item
- 認証情報・Git メタデータ等は除外フィルタ（Test-FileExcluded）でスキップ
- ディレクトリ系は再帰的に各ファイルを除外フィルタ適用しつつコピー

### Phase 4: git status で変更検出
- repo/ で `git status --short`
- 変更なし → 「変更なし。push をスキップして終了」exit 0

### Phase 5: 動作モード分岐

| モード | 動作 |
|-------|------|
| `--dry-run` | git status 出力を表示して exit 0（commit/push/PR なし）|
| `--yes` なし | 「実 push するには -Yes フラグを付けて再実行」exit 0 |
| `--yes` 指定 | Phase 6 以降へ |

### Phase 6: 新ブランチ作成

新ブランチ名: `<branch-prefix>-<scope>-<YYYYMMDD-HHmmss>`（既定 prefix: `sync-from-local`）

- `git checkout -b <new-branch>` を実行
- 失敗時は exit 1（規定ブランチのままで終了）

### Phase 7: commit + push

- `git add -A`
- `git commit -m <message>`（既定: `sync from local <ISO8601>`）
- `git push -u origin <new-branch>`
- いずれかが失敗時:
  - 規定ブランチに復帰を試行（ベストエフォート）
  - 新ブランチを削除（push 失敗時を除く）
  - exit 1

### Phase 8: 規定ブランチに復帰

- `git checkout <remote_branch>` を実行
- スキル起動前と同様の状態（規定ブランチの内容）に復帰
- 失敗時は warning 出力（手動 checkout を案内）

### Phase 9: PR 作成（`--no-pr` 未指定時）

- `gh` CLI 存在確認 → 不在ならスキップ + 手動作成案内
- 存在時: `gh pr create --base <remote_branch> --head <new-branch> --title <title> --body <body>`
- 既定 title: `[sync-settings] <scope> マッピングからの自動同期 (<timestamp>)`
- 既定 body: scope / localBase / targets / commit / new-branch / base を含む構造化テキスト
- 失敗時は warning + 手動作成案内（base / head / repo を提示）

### Phase 10: 完了報告

| 項目 | 内容 |
|-----|------|
| Repo | <remote_repo> |
| Base | <remote_branch> |
| Head branch | <new-branch> |
| Commit | <message> |
| PR | <URL> または「未作成・手動対応が必要」 |

## 期待出力

| シナリオ | 出力 |
|---------|-----|
| dry-run | git status 差分 + `(dry-run) git add / commit / push は行いません。` |
| 変更なし | `(変更なし。push をスキップして終了)` exit 0 |
| 正常完了 | 新ブランチ作成 + commit + push + 規定ブランチ復帰 + PR URL |
| PR 作成失敗 | warning + 手動 PR 作成案内（gh コマンドの出力を含む）|
| 規定ブランチ復帰失敗 | warning + 手動 `git checkout <branch>` 案内（push と PR は完了済み）|

## 分岐の根拠

このケースが分岐するトリガー:

- 動作モード: `--dry-run` / `--yes` / `--no-pr` の有無
- マッピング有無: マッピング不在時は exit 1
- 変更検出: 変更なし時は push スキップ
- gh CLI 有無: PR 作成可否

## 安全装置

- 認証情報除外（`credentials.json` / `.env` / `*.pem` 等）
- Git メタデータ除外（`.git/`）
- **規定ブランチに直接 push しない**（必ず新ブランチ経由）
- **push 完了後の自動復帰**（スキル起動前と同様の状態を保持）
- `--yes` 必須化（誤 push 防止）
- 対話モード時の AskUserQuestion 最終確認
- 失敗時のロールバック（新ブランチ削除 + 規定ブランチ復帰のベストエフォート）

## 設計意図

- **PR ベースワークフロー**: 規定ブランチへの直接書き込みを避けて、レビュー / マージプロセスを介する運用に対応
- **新ブランチの命名一意性**: タイムスタンプを含めることで、複数同期のコリジョン回避
- **規定ブランチ復帰**: ローカル repo/ を起動前と同様の状態に戻すことで、後続の pull や他コマンドとの干渉を防止
- **PR 作成失敗の通知**: gh CLI 不在や認証エラー時にユーザに明示的に通知し、手動対応を促す
- **`--no-pr` フラグ**: 独自の PR 作成ワークフローを持つ環境向けの逃げ道

## エラー処理

| エラー | 対応 |
|-------|------|
| マッピング不在 | exit 1、`/sync-map-set` 案内 |
| 変更なし | exit 0、「push をスキップ」 |
| Git CLI 不在 | exit 1、インストール案内 |
| 新ブランチ作成失敗 | exit 1、エラーメッセージ |
| git add/commit/push 失敗 | exit 1、規定ブランチ復帰 + 新ブランチ削除（ベストエフォート）|
| 規定ブランチ復帰失敗 | warning + 手動 `git checkout` 案内（push と PR は完了済み）|
| gh CLI 不在 | warning + 手動 PR 作成案内 |
| gh pr create 失敗（認証 / ネットワーク） | warning + gh 出力提示 + 手動 PR 作成案内 |

## 関連ケース

- `case-13_map_set_interactive.md`（マッピング設定）
- `case-17_pull_interactive_strategy.md`（pull の interactive 戦略）
- 既存 case-08（認証情報自動除外）— push でも同等のフィルタが適用される

## 関連ドキュメント

- gh CLI インストール: <https://cli.github.com/>
- gh CLI 認証: `gh auth login`
