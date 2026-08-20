# harness-init 実行手順詳細

## Phase 1: 前提確認

| 検査 | 方法 | NG 時の動作 |
|------|------|------------|
| git リポジトリ | `git rev-parse --show-toplevel` | `git init` の実施を提案（拒否時は中断。SHA 基準の同期ができないため）。**非対話モードでは提案せず中断**（無確認 `git init` 禁止） |
| 既存ハーネス | `.claude/references/.sync-state.json` の存在 | `harness-update` への切替を提案。「再構築して」等の明示指示時のみ、既存内容の扱い（保持マージ / 退避 / 破棄）を `AskUserQuestion` で確認して続行。**非対話モードでは切替提案のみで中断**（無確認再構築禁止） |
| 部分的既存 | `.claude/CLAUDE.md` や `references/` の一部のみ存在（`.sync-state.json` なし） | 既存部分は保持し、不足分のみ生成（既存内容は Phase 4 でマージ。既存ファイルの上書きが必要な場合は個別に `AskUserQuestion` で確認） |
| コミット有無 | `git rev-parse HEAD` | コミットが 1 つもない場合、初回コミット後の実行を案内して中断 |

再構築時の既存内容の扱い（`AskUserQuestion` の 3 択）:

| 選択 | 動作 |
|------|------|
| 保持マージ | 既存ドキュメントを残し、新解析結果との差分をマージする（既存の記載が優先。矛盾はユーザに提示） |
| 退避 | `.claude/references/` 全体を `.claude/references-backup-<yyyyMMdd>/` へ移動してから全量を新規生成する |
| 破棄 | `.claude/references/` 配下と `.claude/CLAUDE.md` を削除して全量を新規生成する（削除範囲を提示し、最終確認を経てから実施） |

## Phase 2: 既存資産調査

検出対象と取り込み方針:

| 資産 | 検出方法 | 取り込み先 |
|------|---------|-----------|
| ルート `CLAUDE.md` | ルート直下 | 概要・技術スタック → `.claude/CLAUDE.md`、詳細情報 → `references/` 該当フォルダ |
| `README.md` | ルート直下 | プロジェクト概要・セットアップ手順 → `.claude/CLAUDE.md` / `environments/` |
| `docs/` 等の既存ドキュメント | Glob（`docs/**/*.md` 等） | 内容に応じて specs / system-designs / architecture へ要約転記（原本は不変） |
| `.editorconfig` / linter 設定 | ルート・設定ファイル | `conventions/` の根拠 |
| CI 設定（`.github/workflows/` 等） | 該当ディレクトリ | `environments/` の検証コマンド根拠 |

対話モードでは取り込み対象を提示し、`AskUserQuestion` で確認する（既定: すべて取り込み）。

ルート `CLAUDE.md` が既存の場合の整理（取り込み後にルート側を「`.claude/CLAUDE.md` への参照 1 行」に置き換える対応）は、**ユーザが承認した場合のみ** 実施する。非対話モードでは整理せず両立のまま残し、報告に含める。

## Phase 3: プロジェクト解析

[agents.md](agents.md) の定義に従い、調査サブエージェントを **並列起動** する。各エージェントには以下を必ず含めて指示する:

- 対象プロジェクトのルートパス
- 調査観点（agents.md の担当領域）
- 「ソースから確認できた事実のみを報告し、推測は『推測』と明示する」制約
- 返却フォーマット（機能一覧は「機能名 / 対応ソースパス / 概要」の表）

統合後、機能・画面一覧を規模順に提示し、初期ドキュメント生成範囲を確認する:

| モード | 生成範囲の決定 |
|-------|---------------|
| 対話 | 機能一覧を提示し `AskUserQuestion`（全機能 / 主要機能のみ / 個別選択） |
| 非対話 | 主要機能（アプリの中核をなす画面・業務。目安 5〜10 件）を自動選定し、残りは各フォルダ `CLAUDE.md` に「未文書化機能リスト」として記録 |

## Phase 4: ハーネス生成

### 生成順序

1. フォルダ作成: `references/{specs,system-designs,flows,environments,conventions,architecture,decisions}/`
2. 葉のドキュメント生成（テンプレート → 解析結果で置換）:
   - `environments/`（検証コマンドはこの時点で **実行確認** し、動作したものだけを記載。未確認は `TODO:`）
   - `conventions/` / `architecture/` / `specs/` / `system-designs/` / `flows/`
   - `decisions/`（既存資産・コード実態から読み取れた判断のみ。無ければ雛形なしで `CLAUDE.md` のみ）
   - `glossary.md`（コード・既存ドキュメントから抽出した用語）
3. 各フォルダの `CLAUDE.md` 索引生成（実体と一致させる）
4. `references/CLAUDE.md` 生成
5. `.claude/CLAUDE.md` 生成（100 行以内）
6. `.sync-state.json` 初期化

### 生成量が多い場合のエージェント委譲

生成対象ドキュメントが 10 件を超える場合、フォルダ単位でサブエージェントに生成を委譲してよい（[agents.md](agents.md) の生成エージェント参照）。委譲時はテンプレートパスと frontmatter 規則・捏造禁止制約をプロンプトに含め、メインが全生成物の frontmatter / インデックス整合を最終確認する。

### gitignore 検査

`.claude/.local/` が対象プロジェクトの `.gitignore` に含まれるか確認し、無ければ追記を提案する（ハーネス本体 `.claude/CLAUDE.md` / `references/` はコミット対象のため ignore しない）。

## Phase 5: 同期状態の初期化

```json
{
  "last_synced_commit": "<git rev-parse HEAD の結果>",
  "last_synced_at": "<現在時刻 ISO 8601>",
  "initialized_at": "<現在時刻 ISO 8601>",
  "threshold_commits": 10
}
```

未コミット変更が存在する場合、その内容はドキュメントに反映済みでも同期基準は HEAD になる旨を報告する（コミット後の `/project-harness:update` は差分ゼロ扱いにならないが、sources 照合で「反映済み」と判定される）。

## Phase 6-7: 検証・報告

SKILL.md の検証チェックリストを実施後、以下を報告する:

- 生成ファイル一覧（フォルダ別件数）
- 解析サマリ（技術スタック・文書化した機能数 / 未文書化機能数）
- `TODO:` 残数と代表例（ユーザに確認してほしい未確認事項）
- 運用案内: `/project-harness:update`・鮮度通知フック・`threshold_commits` の調整方法
