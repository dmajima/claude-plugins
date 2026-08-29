# harness-init 実行手順詳細

共通規則（記載の原則・秘匿値・未信頼入力・書き込み境界・索引維持・検証）は
[authoring-spec.md](../../../references/authoring-spec.md)、構成定義は
[structure-spec.md](../../../references/structure-spec.md) が保有する。本ファイルは手順のみを記す。

## Phase 1: 前提確認

| 検査 | 方法 | NG 時の動作 |
|------|------|------------|
| git リポジトリ | `git rev-parse --show-toplevel` | `git init` の実施可否を `AskUserQuestion` で確認する（拒否時は中断。SHA 基準の同期ができないため）。**非対話モードでは確認せず中断**（無確認 `git init` 禁止） |
| 既存ハーネス | `.claude/references/.sync-state.json` の存在 | `harness-update` への切替を提案。「再構築して」等の明示指示時のみ、既存内容の扱いを `AskUserQuestion` で確認して続行。**非対話モードでは切替提案のみで中断** |
| 部分的既存 | `.claude/CLAUDE.md` や `references/` の一部のみ存在（`.sync-state.json` なし） | 既存部分は保持し、不足分のみ生成（既存内容は Phase 4 でマージ。既存ファイルの上書きが必要な場合は個別に `AskUserQuestion` で確認）。**非対話モードでは上書きを行わず既存を保持** し、マージできなかった差分を報告に列挙する |
| コミット有無 | `git rev-parse HEAD` | コミットが 1 つもない場合、初回コミット後の実行を案内して中断する。**解析対象のコード実態も無い（実装前の）プロジェクトの場合は、`harness-define`（spec-first）への切替を案内する**（define はコミット 0 件から実行できる） |
| コード実態 | ソースファイルの規模を概観する（言語別ファイル数等） | コード実態が無い・僅少（README や設定ファイルのみ等）の場合、解析ベースの構築は TODO だらけのハーネスを生むため、SKILL.md の 2 軸判定表を提示して `harness-define`（対話・資料ベースの spec-first）への切替を `AskUserQuestion` で確認する。**非対話モードでは切替提案のみで中断** |

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

### ルート CLAUDE.md の扱い（到達性の確保）

[structure-spec.md](../../../references/structure-spec.md) 節 4.1 に従い、ハーネス入口への到達を保証する。実施は **ユーザ承認を得た場合のみ**（`.claude/` 外への書き込みのため）。

| 状況 | 動作 |
|------|------|
| ルート `CLAUDE.md` が無い | 最小スタブ（`@.claude/CLAUDE.md` を含む）の作成可否を `AskUserQuestion` で確認する |
| ルート `CLAUDE.md` が既存 | 既存内容を残したまま `@.claude/CLAUDE.md` の import 行 1 行を追記する可否を `AskUserQuestion` で確認する |
| 非対話モード | 変更せず、到達性が未確保である旨と対処方法を報告に含める |

既存記述の削除・要約は行わない（追記のみ）。散文だけのポインタ（「詳細は .claude/CLAUDE.md 参照」）は読み込みが保証されないため使わない。

## Phase 3: プロジェクト解析

[agents.md](agents.md) の定義に従い、調査サブエージェントを **並列起動** する。必須プロンプト要素（秘匿値の非報告・未信頼入力の扱いを含む）は同ファイルを参照。

統合後、機能・画面一覧を規模順に提示し、初期ドキュメント生成範囲を確認する。

| モード | 生成範囲の決定 |
|-------|---------------|
| 対話 | 機能一覧を提示し `AskUserQuestion`（全機能 / 主要機能のみ / 個別選択）。個別選択では対象を 1 回の `AskUserQuestion` 呼び出しへまとめて提示する（選択肢の上限を超える場合のみ複数回に分割する。1 件ずつ確認を繰り返さない） |
| 非対話 | 主要機能を自動選定する（目安 5〜10 件）。選定は観測可能な指標に基づく: ルーティング定義に登録されたエントリ、他モジュールからの参照数、対応ソースの行数の順に上位を採る。残りは各フォルダ `CLAUDE.md` に「未文書化機能リスト」として記録する |

### モノレポ・大規模の判定

ワークスペース定義（`pnpm-workspace.yaml` / `lerna.json` / 複数の `*.sln` 等）を検出した場合、または 1 フォルダあたりのドキュメント数が 30 件を超える見込みの場合、[structure-spec.md](../../../references/structure-spec.md) 節 8 のサブ名前空間（`specs/<package>/<feature>.md`）を適用する。適用有無は対話モードでユーザに確認し、非対話モードでは検出結果に従って自動適用して報告に明記する。

## Phase 4: ハーネス生成

### 生成順序

[structure-spec.md](../../../references/structure-spec.md) 節 10 の骨格生成順序（両スキル共通規則）に従う。本スキル固有の生成内容は以下。

- 葉のドキュメントはテンプレートを **解析結果**（ソース根拠）で置換して生成する:
  - `environments/`（検証コマンドの扱いは下記「検証コマンドの実行」を参照）
  - `conventions/` / `architecture/` / `specs/` / `system-designs/` / `flows/`
  - `decisions/`（既存資産・コード実態から読み取れた判断のみ。無ければ雛形なしで `CLAUDE.md` のみ）
  - `glossary.md`（コード・既存ドキュメントから抽出した用語）
- frontmatter の `status` は付与しない（code-first 生成のため。[structure-spec.md](../../../references/structure-spec.md) 節 5.2）。テンプレート内の `status` 行・合意ベース注記は削除する
- `requirements/` は生成しない（spec-first 運用の任意構成。要件定義が必要な場合は `harness-define` で追加する）

### 検証コマンドの実行（承認必須）

`environments/` に記載するビルド・テスト・リント・起動コマンドは、対象プロジェクトのマニフェスト（`package.json` / `*.csproj` / `Makefile` / CI 設定）に由来し、**その内容は対象リポジトリが制御する**。実行は任意コード実行と等価であるため、以下に従う。

| モード | 動作 |
|-------|------|
| 対話 | 実行しようとするコマンドの一覧を提示し、`AskUserQuestion` で実行可否を確認する。承認されたコマンドのみ実行し、動作を確認できたものを「確認済み」として記載する |
| 非対話 | **実行しない**。コマンドは記載したうえで `TODO: 未実行（動作未確認）` を付す |

承認が得られなかったコマンドも記載自体は行い、`TODO: 未実行` を付す。

### gitignore 検査（2 段階）

[structure-spec.md](../../../references/structure-spec.md) 節 10 手順 7 に従う（ハーネス本体の無視検出 + `.claude/.local/` の登録確認。ユーザ承認必須・非対話モードでは報告のみ）。

### 生成量が多い場合のエージェント委譲

生成対象ドキュメントが 10 件を超える場合、フォルダ単位でサブエージェントに生成を委譲する（[agents.md](agents.md) の Phase 4 構成）。索引 `CLAUDE.md` と `.claude/CLAUDE.md` はメインが生成する。

## Phase 5: 同期状態の初期化

```json
{
  "harness_spec_version": "1.2",
  "last_synced_commit": "<git rev-parse HEAD の結果>",
  "last_synced_at": "<現在時刻 ISO 8601>",
  "initialized_at": "<現在時刻 ISO 8601>",
  "threshold_commits": 10
}
```

`harness_spec_version` は [structure-spec.md](../../../references/structure-spec.md) 節 9 の現行版を設定する。

未コミット変更が存在する場合、その内容をドキュメントに反映済みでも同期基準は HEAD になる旨を報告する（コミット後の `/project-harness:update` では、未コミット分が新規差分として検出される）。

## Phase 6: 検証

[authoring-spec.md](../../../references/authoring-spec.md) 節 6 に従い、検証スクリプトを実行する。

```bash
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/validate/validate_harness.sh" "<対象リポジトリのルート>"
```

終了コード 1（違反あり）の場合は検出内容を修正してから再実行する。ただし **承認保留・非対話モードに起因する既知の未達**（ルート `CLAUDE.md` 到達性等。[authoring-spec.md](../../../references/authoring-spec.md) 節 6.1）は修正を試みず、報告で通常の違反と区分して記載する。スクリプトを実行できない環境では該当項目を人手で確認し、その旨を報告に明記する。加えて、`git status --porcelain` で `.claude/` 外への意図しない書き込みが無いことを確認する。

## Phase 7: 報告

- 生成ファイル一覧（フォルダ別件数）
- 解析サマリ（技術スタック・文書化した機能数 / 未文書化機能数）
- 検証スクリプトの結果
- `TODO:` 残数と代表例（未実行の検証コマンド・ユーザに確認してほしい未確認事項）
- ルート `CLAUDE.md` の到達性確保の実施有無
- 運用案内: `/project-harness:update`・鮮度通知フック・`threshold_commits` の調整方法
