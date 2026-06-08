# スクリプト記述・配置ポリシー（MANDATORY）

`extension-toolkit` プラグインが管理するすべての拡張要素（スキル・コマンド・エージェント・フック・プラグイン本体）に適用される、スクリプト（Python・Bash・PowerShell・Node 等）の記述場所と配置ルール。本ポリシーは [`conventions.md`](conventions-structure.md) の補足として、スクリプトに特化した詳細を定義する。

OK/NG 例は `../procedures/scripts-examples.md`、移行ガイドは `../procedures/scripts-examples.md` を参照。

## 1. 基本原則

| 原則 | 内容 |
|-----|------|
| **インラインスクリプト禁止** | `references/`・`SKILL.md`・`README.md` 等の Markdown ファイルに、実行を意図したスクリプトをコードブロックで直接記載しない |
| **`references/scripts/` 配下に配置** | 実行可能スクリプトは必ず `references/scripts/{業務単位}/` 配下にファイルとして配置し、md からはパス参照する |
| **コマンド実行は md 直接記載 OK** | 単発のシェルコマンド（`mkdir` `git status` `ls` 等）や、引数 1〜2 個の単純な呼び出しは Markdown に直接記載してよい |
| **プラグイン単位 venv** | Python venv はプラグイン単位で 1 つ作成・管理する。スキル単位で個別に venv を持たない |
| **venv ライフサイクル事前スクリプト化** | venv の構築・撤去は **プラグイン直下** の `references/scripts/setup/` に事前ビルドしたスクリプトを呼ぶだけにする（その都度生成しない）|
| **Python 不使用なら venv 不要** | プラグイン全体で Python を使用しない場合、venv 関連スクリプトの設置義務はない |

## 2. 配置構造（2 階層）

`	ext
plugins/{plugin-name}/
├── references/
│   └── scripts/                      <- プラグイン共通リソース（全スキルから参照可）
│       └── setup/
│           ├── setup_venv.sh        # venv 構築 + 依存インストール
│           ├── teardown_venv.sh     # venv 削除
│           └── requirements.txt      # 全スキルの依存をマージしたリスト
└── skills/
    └── {skill-name}/
        └── references/
            └── scripts/              <- スキル固有スクリプト
                └── {業務単位}/
                    └── {実スクリプト}
`

| 階層 | 配置 | 用途 |
|-----|------|------|
| プラグイン直下 | `plugins/{name}/references/scripts/` | プラグイン共通スクリプト（venv 関連は必ずここ） |
| スキル直下 | `plugins/{name}/skills/{skill}/references/scripts/` | スキル固有の業務スクリプト（venv は持たない） |

スキルから参照するときのポータブルパス記法:

| 対象 | 記法 |
|-----|------|
| プラグイン共通スクリプト | `/references/scripts/setup/setup_venv.sh` |
| スキル固有スクリプト | `/references/scripts/{業務単位}/{name}` |

## 3. インラインスクリプトの判定基準

### 3.1 NG（必ず `references/scripts/` に切り出す）

以下に該当する場合は **必ずファイル化** する:

- 行数が **6 行以上**（コードフェンス内の実行行数。空行・コメントは除く）
- 制御構造（`if` / `for` / `while` / `function`）を含む 5 行以上
- 引数を取る・複数の責務を持つ
- 複数の md から再利用される（または再利用が見込まれる）
- ヒアドキュメント・複雑な変数展開・パイプチェーン 3 段以上を含む
- エラーハンドリング・例外処理を含む

### 3.2 OK（md に直接記載してよい）

以下は md 内のコードブロックに直接書いてよい:

- 単発のシェルコマンド（最大 5 行・1 責務）
- ファイル / ディレクトリ操作（`mkdir` `mv` `cp` `rm` 単発）
- Git 単一コマンド（`git status` `git log` 等）
- 設定確認系コマンド（`cat` `ls` `wc -l` 等）
- スクリプトファイルへの **呼び出し方** を示す例
## 5. プラグイン単位 venv

### 5.1 配置

| 階層 | ファイル | 役割 |
|-----|--------|------|
| プラグイン直下 | `references/scripts/setup/setup_venv.sh` | venv 構築 + 依存インストール |
| プラグイン直下 | `references/scripts/setup/teardown_venv.sh` | venv 削除 |
| プラグイン直下 | `references/scripts/setup/requirements.txt` | プラグイン全体の依存パッケージ統合リスト |
| セッション作業領域 | `<work_dir>/.venv/` | 実体（ユーザの作業セッションに紐づく一時領域） |

### 5.2 必須要件

- venv は **プラグイン単位で 1 つ**。複数スキルが協業する場合も同じ venv を再利用する
- `setup_venv.sh` / `teardown_venv.sh` / `requirements.txt` は **プラグイン直下** の `references/scripts/setup/` に配置する
- スキル配下に独自の `references/scripts/setup/` を置いてはならない（重複・乖離防止）
- 各スキルは setup スクリプトを **呼び出すだけ**（独自に venv を作成・破棄しない）
- `requirements.txt` は **全スキルの依存をマージ** したものとする（スキルごとの個別 requirements.txt は禁止）

### 5.3 例外（venv 不要なケース）

以下に該当するプラグインは venv 関連スクリプトを設置しなくてよい:

- プラグイン全体で Python を一切使用しない（Node のみ等）
- 利用する Python が標準ライブラリのみで完結し、外部依存パッケージが無い

判断基準: `references/scripts/` 配下に `.py` ファイルが存在し、かつ標準ライブラリ以外の `import` を含む場合は venv 必須。

### 5.4 venv のライフサイクル

呼び出し側（各スキル）は以下の 3 ステップのみを実施する:

`ash
# 1. 構築（セッション開始時）
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/setup_venv.sh" -WorkDir "$SessionDir/workspace"

# 2. Python 実行（Start-Job ラッパー経由必須・5.5 参照）
bash "$CLAUDE_SKILL_DIR/references/scripts/{業務}/run_via_job.sh" -PythonExe "$SessionDir/workspace/.venv/Scripts/python.exe"

# 3. 撤去（セッション完了時）
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/teardown_venv.sh" -WorkDir "$SessionDir/workspace"
`

venv 内部のロジック（python コマンド検出・pip 操作・OS 別パス分岐等）はすべて setup スクリプト側で完結させる。

### 5.5 Python 子プロセス起動は Start-Job 経由ラッパー必須（MANDATORY）

Windows + PowerShell から Python スクリプトを `Start-Process -NoNewWindow` または `&` + ファイルリダイレクトで直接起動すると、ライブラリ（`python-pptx.Presentation` 等）の呼び出しでハングする既知事象がある。グローバルルール `~/.claude/rules/tools/python-subprocess-hang-windows.md` 参照。

**Python スクリプトを呼ぶ拡張要素（スキル / コマンド）を作る場合、必ず Start-Job 経由ラッパーを `references/scripts/{業務}/` に同梱**し、procedures.md 等の起動例ではラッパー経由のみを示すこと。

| 項目 | 内容 |
|------|------|
| ラッパーファイル名 | `run_via_job.sh` を推奨（業務単位ごとに別名でも可）|
| 必須実装要素 | `Start-Job` + `Wait-Job -Timeout` + `Receive-Job` + `Stop-Job`/`Remove-Job` のクリーンアップ |
| 必須プリフィクス | ジョブ ScriptBlock 内で `chcp.com 65001` + `[Console]::OutputEncoding = UTF8` + `System.Text.UTF8Encoding+UTF8EncodingSealed = UTF8` + `1=1` + `utf-8=utf-8` |
| Python 実行 | `&  -u  @jobArgs` の形（`-u` で unbuffered）|
| 終了コード返却 | `return ` を ScriptBlock 末尾に置き、`Receive-Job` から取り出して `exit ` |
| 実装サンプル | `plugins/convert-doc/references/scripts/convert-from-pptx/run_via_job.sh` |
## 6. インラインで残してよいコードブロック

以下は「実行スクリプト」ではなく **設定ファイル例 / 出力例 / フォーマット例** であり、本ポリシーの対象外（残してよい）:

| 種別 | 例 |
|-----|---|
| YAML frontmatter のサンプル | `description:` `name:` 等の例 |
| JSON 設定ファイルのサンプル | `plugin.json` `marketplace.json` の例 |
| 出力フォーマット例 | エラーメッセージ・JSON 出力構造の例 |
| 構造ツリー（コードブロック内）| `plugins/foo/references/scripts/...` のディレクトリ図 |
| インラインで動作の解説に必要な短い疑似コード | `# pseudocode:` 等の明示があるもの |

判断基準: **そのコードブロックを Claude が実行することが期待されているか**。実行されるなら `references/scripts/` に切り出す。表示専用なら md に残してよい。

## 7. レビュー観点（extension-reviewer 連携）

`extension-reviewer` の `references/scripts/checks/run_checks.py` は本ポリシーの違反を以下の方法で検出する:

| 検出項目 | 重大度 | 検出方法 |
|---------|-------|--------|
| md 内 6 行以上のコードブロック（`bash` / `python` / `sh` / `powershell` 等の言語指定あり） | High | フェンス間の行数カウント |
| 制御構造を含む md 内コードブロック（`if `/`for `/`while `/`function ` を含む 5 行以上） | High | パターン検出 |
| プラグイン直下 `references/scripts/setup/setup_venv.sh` 不在（`.py` ファイルが 1 つ以上ある場合） | High | ファイル存在確認 + `*.py` 検出 |
| スキル直下 `references/scripts/setup/setup_venv.sh` 存在（プラグイン直下と重複） | High | ファイル存在確認 |
| スキルごとの個別 `requirements.txt` 存在 | Medium | ファイル存在確認 |
| トップレベル `scripts/` 直下配置（旧ルール残存）| High | ディレクトリ存在確認（`plugins/{name}/scripts/` または `plugins/{name}/skills/{skill}/scripts/`） |

## 9. extension-toolkit 同梱フック（ADR-026）

プラグイン同梱フック `hooks/hooks.json` で 2 種類のフックを登録する。**警告型 + コミット前 version 検証** の 2 段構成（ADR-026）。

| フック | タイミング | スクリプト | 動作 |
|-----|---------|---------|-----|
| `PreToolUse Edit/Write/MultiEdit` | 編集直前 | `references/scripts/hooks/enforce_toolkit_routing.sh` | `plugins/{name}/` 配下なら推奨スキル名を stderr 提示、**exit 0**（ブロックしない） |
| `Stop` | Claude ターン終了時 | `references/scripts/hooks/check_version_bump.sh` | `plugins/{name}/` の未コミット変更で `plugin.json` の version が main から未更新なら stderr 警告、**exit 0**（fail-open） |

| 項目 | 内容 |
|-----|------|
| 除外パス | `.claude/.local/` / `.git/` 配下、git 利用不可環境、リポジトリ外、ファイルパス取得失敗時 |
| 設計方針 | ハードブロック型ではなく警告型を採用。軽微な編集体験を妨げず、真因（バージョン更新漏れ）には Stop フックで直接対処 |

詳細は `../architecture/decisions-021-033.md` ADR-026 を参照。

## 10. 関連ルール

| ルール | 関係 |
|-------|------|
| [`conventions.md`](conventions-structure.md) | スクリプト配置の上位規約（本ポリシーで詳細化） |
| [`../checklists/validation-rules.md`](../checklists/validation-rules.md) | 機械検証項目（本ポリシーの違反検出） |
| `../architecture/decisions-021-033.md` | ADR-024（プラグイン単位 venv）・ADR-025（インラインスクリプト禁止 + `references/scripts/` 配置義務）・ADR-026（経由強制フック） |
| [`../policies/path-portability.md`](../policies/path-portability.md) | スクリプト内のパス記述ルール |
| 各スキルの `references/scripts/checks/run_checks.py`（extension-reviewer） | 本ポリシーの自動検出 |
| `hooks/hooks.json` + `references/scripts/hooks/enforce_toolkit_routing.sh` + `check_version_bump.sh`（本プラグイン同梱） | toolkit 経由の推奨提示（PreToolUse 警告型）+ バージョン更新漏れ検証（Stop）、ADR-026 |