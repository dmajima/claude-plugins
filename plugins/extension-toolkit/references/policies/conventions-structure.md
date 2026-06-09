# ディレクトリ構造規約

`extension-toolkit` プラグイン配下の全スキル・全成果物が従うべきディレクトリ構造規約。

階層別の厳格度:

| 階層 | 厳格度 | 内容 |
|-----|-------|------|
| プラグイン直下 | **厳格（許可リスト運用）** | 列挙されたディレクトリ・ファイル以外を置かない |
| スキル直下 | **厳格（許可リスト運用）** | 同上 |
| `references/` 直下 | 推奨例（緩い） | 推奨される命名・配置を例示。実情に応じて拡張可 |
| `scripts/` 直下 | 推奨例（緩い） | 推奨される業務単位サブフォルダを例示。`knowledge/` 等の禁止項目のみ厳格 |

本ファイルはディレクトリ構造規約（旧 `conventions.md` 節 2〜5 に対応）。命名規約（節 1・6・7）は [`conventions-naming.md`](conventions-naming.md)、共通規約・禁止事項（節 8〜14）は [`conventions-general.md`](conventions-general.md) を参照。

## 2. プラグイン直下の構造（**厳格運用**）

### 2.1 許可されるエントリ（完全列挙、これ以外禁止）

```text
plugins/{plugin-name}/
├── .claude-plugin/                # 必須（Claude Code 公式仕様）
│   └── plugin.json                # 必須（license: "MIT" 必須、ADR-029）
├── README.md                      # 必須（人間向けリファレンス、../readme-policy.md 準拠）
├── LICENSE                        # 必須（MIT 標準文、ADR-029 / license-policy.md 準拠）
├── commands/                      # 任意（Claude Code 公式仕様）
│   └── {command-name}.md
├── skills/                        # 任意（Claude Code 公式仕様、節 3 で詳述）
│   └── {skill-name}/
│       └── ...
├── agents/                        # 任意（Claude Code 公式仕様、サブエージェント定義）
│   └── {agent-name}.md
├── hooks/                         # 任意（Claude Code 公式仕様）
│   └── hooks.json
├── mcp/                           # 任意（Claude Code 公式仕様）
│   └── ...
├── assets/                        # 任意（独自、実行時の共通静的リソース、ADR-030）
│   ├── css/
│   ├── html/
│   └── ...
└── references/                    # 任意（独自、SSOT・チーム定義・テンプレート集約。節 4 で詳述）
    └── ...
```

### 2.2 許可リストの根拠

| エントリ | 由来 | 必須/任意 |
|---------|------|----------|
| `.claude-plugin/plugin.json` | Claude Code 公式 | 必須 |
| `README.md` | 独自ルール（[`../readme-policy.md`](readme-policy.md)） | 必須 |
| `LICENSE` | 独自ルール（[`license-policy.md`](license-policy.md)、ADR-029） | 必須（MIT 標準文 + Copyright 行を `mit-license-toolkit` が生成） |
| `commands/` | Claude Code 公式 | 任意 |
| `skills/` | Claude Code 公式 | 任意 |
| `agents/` | Claude Code 公式 | 任意 |
| `hooks/` | Claude Code 公式 | 任意 |
| `mcp/` | Claude Code 公式 | 任意 |
| `assets/` | 独自（実行時の共通静的リソース、ADR-030） | 任意 |
| `references/` | 独自（SSOT・ナレッジ・スクリプト集約。`references/scripts/` 配下に共通スクリプト、ADR-024 / ADR-025） | 任意（Python 利用プラグインでは `references/scripts/setup/` 必須） |

### 2.3 配置の禁止

| 禁止 | 理由 |
|-----|------|
| プラグイン直下に `teams/` を置く | 独自構造は `references/` 配下に集約（ADR-002） |
| プラグイン直下に `templates/` を置く | 同上 |
| プラグイン直下に `shared/` `common/` `lib/` 等を置く | `references/` を使う |
| **プラグイン直下に `scripts/` を置く（実スクリプト・サブフォルダ含む）** | 実スクリプトは `references/scripts/` に集約（ADR-025） |
| プラグイン直下に `docs/` を置く | `README.md` + `references/` で完結させる |
| Claude Code 公式 + `references/` 以外のトップレベルディレクトリを追加 | ADR で明示する場合のみ例外 |
| **スキル直下に `references/scripts/setup/setup_venv.sh` 等の venv 関連スクリプトを置く** | プラグイン単位 venv（ADR-024）に違反、プラグイン直下 `references/scripts/setup/` に集約する |
| **スキルごとの個別 `requirements.txt` を作る** | プラグイン直下に統合（ADR-024） |

### 2.4 例外条項

許可リスト外のディレクトリ・ファイルを追加する場合:

| 手順 | 内容 |
|-----|------|
| 1 | [`../architecture-decisions.md`](../architecture/) に新 ADR を追加（決定 / 理由 / トレードオフ / 代替案を必須記載） |
| 2 | 本ファイル節 2.1 の許可リストを更新 |
| 3 | [`../checklists/validation-rules.md`](../checklists/validation-rules.md) の機械チェックを更新 |

ADR 追加なしの追加は **規約違反**。

## 3. スキル直下の構造（**厳格運用**）

### 3.1 許可されるエントリ（完全列挙、これ以外禁止）

```text
plugins/{plugin-name}/skills/{skill-name}/
├── SKILL.md                       # 必須（Claude Code 公式仕様）
├── README.md                      # 必須（独自、../readme-policy.md 準拠）
├── references/                    # 任意（スキル固有の詳細ドキュメント・スキル固有スクリプト、節 5 で詳述）
├── agents/                        # 任意（Claude Code 公式仕様、グローバル重複でも保持）
├── assets/                        # 任意（独自、スキル固有の静的リソース。プラグイン直下と同名なら上書き、ADR-030）
└── evals/                         # 動作分岐ありなら必須（独自）
```

実行可能スクリプトはすべて `references/scripts/` 配下に配置する（ADR-025）。スキル直下に `scripts/` ディレクトリは置かない。

### 3.2 許可リストの根拠

| エントリ | 由来 | 必須/任意 |
|---------|------|----------|
| `SKILL.md` | Claude Code 公式 | 必須 |
| `README.md` | 独自ルール（[`../readme-policy.md`](readme-policy.md)） | 必須 |
| `references/` | 独自（スキル固有の詳細・スクリプト・テンプレート集約） | 任意 |
| `agents/` | Claude Code 公式（プラグイン配布時のサブエージェント） | 任意 |
| `assets/` | 独自（スキル固有の静的リソース、ADR-030） | 任意 |
| `evals/` | 独自（[`../guides/eval-guide.md`](../guides/eval-guide.md)） | 動作分岐ありなら必須 |

### 3.3 配置の禁止

| 禁止 | 理由 |
|-----|------|
| **スキル直下に `scripts/` を置く（実スクリプト・サブフォルダ含む）** | 実スクリプトは `references/scripts/` に集約（ADR-025） |
| `scripts/` の代わりに `knowledge/` `lib/` `bin/` 等 | スキル直下にこれらは置かず `references/scripts/{業務}/` を使う |
| `references/` の代わりに `docs/` `notes/` 等 | エコシステム慣用に反する |
| `agents/` ディレクトリの重複理由による削除 | プラグイン配布先環境に依存できないため保持必須 |
| `tests/` `spec/` 等を直下に置く | 動作分岐の例示は `evals/` を使う |
| 列挙されていないトップレベルディレクトリの追加 | ADR で明示する場合のみ例外 |

### 3.4 例外条項

節 2.4 と同じ運用（ADR 追加 + 許可リスト更新 + 機械チェック更新）。

### 3.5 SKILL.md の制約

| 制約 | 値 |
|-----|---|
| 行数上限 | 200 行 |
| 必須フィールド | `name` `description`（frontmatter） |
| `name` の一致 | ディレクトリ名と完全一致 |
| 必須セクション | 責務 / 責務外 / トリガー条件 / 前提 / 実行モード判定 / 実行フロー / 重要な制約 / 参照 |
| 内容粒度 | 概要・トリガー条件・基本フロー概要のみ（詳細は `references/` に分離） |

## 4. references/ 直下の構造（**推奨例**）

### 4.1 推奨される配置

`references/` は **「ナレッジ・SSOT・テンプレート・実行スクリプト」をまとめて集約する独自リソース領域** である。「読み物専用」ではなく、`references/scripts/` 配下に実行可能スクリプトを配置する設計（ADR-025）。実情に応じて拡張可（厳格な許可リストではない）。

推奨構造:

```text
references/
├── README.md              # 必須（人間向けインデックス。エージェント動作では参照禁止）
├── CLAUDE.md              # 必須（Claude エージェント向け原則・ナビゲーション。claude-md-policy.md 準拠）
├── policies/              # ポリシー・制約ルール
├── guides/                # ガイド・設計指針
├── checklists/            # チェックリスト・検証
├── procedures/            # 手順・業務フロー
├── architecture/          # ADR
├── templates/             # テンプレート
├── teams/                 # チーム定義
└── scripts/               # スクリプト
```

### 4.2 references/ 直下の運用ルール（緩い）

| 観点 | ルール |
|-----|------|
| ファイル分割粒度 | 業務単位ごと（命名・規約・ガイド・テンプレート等） |
| サイズ閾値 | **200 行を目安上限、300 行超は分割必須** |
| ファイル分離原則 | ポリシー・ガイド・チェックリスト・手順・テンプレート・ADR は別ファイルで管理。1 ファイルに混在させない |
| 命名 | kebab-case + 用途名 |
| カテゴリサブディレクトリ | `policies/` `guides/` `checklists/` `procedures/` `architecture/` を推奨（プラグインの規模・性質に応じて拡張可） |
| `teams/` `templates/` の配置 | references/ 配下を推奨（プラグイン直下には置かない、ADR-002） |
| 分割時の相互参照 | ファイルを分割した場合、元ファイル・新ファイル双方に相互参照リンクを入れる。読者が来訪経路を辿れるようにする |

### 4.3 スキル内 `references/` の運用

スキル直下の `references/` も同様の緩い運用。推奨ファイル:

```text
references/
├── procedures.md         # 実行手順詳細
├── setup.md              # 環境構築（Python 利用時）
├── rules.md              # 詳細ルール
├── {topic}.md            # その他、業務単位ごと
└── template/             # スキル固有テンプレート（任意）
```

## 5. references/scripts/ 配下の構造（**推奨例 + 一部禁止項目**）

実行可能スクリプトはすべて `references/scripts/` 配下に集約する（ADR-025）。配置は **2 階層**:

| 階層 | 配置 | 用途 |
|-----|------|------|
| プラグイン直下 | `plugins/{plugin-name}/references/scripts/` | プラグイン共通スクリプト（venv 関連は必ずここ） |
| スキル直下 | `plugins/{plugin-name}/skills/{skill-name}/references/scripts/` | スキル固有の業務スクリプト（venv は持たない） |

### 5.1 プラグイン直下 `references/scripts/`（ADR-024）

`setup/` が標準サブフォルダ。Python を利用するプラグインでは **必須**。

```text
plugins/{plugin-name}/references/scripts/
└── setup/
    ├── setup_venv.sh       # venv 構築 + 依存インストール
    ├── teardown_venv.sh    # venv 削除
    └── requirements.txt     # 全スキルの依存統合リスト
```

| ルール | 内容 |
|-------|------|
| Python 利用時 | `setup_venv.sh` `teardown_venv.sh` `requirements.txt` 必須 |
| Python 未利用時 | `references/scripts/setup/` 自体を省略可能 |
| venv は **プラグイン単位 1 つ** | 複数スキル協業時も同一 venv を再利用 |
| `requirements.txt` は **マージ済リスト** | スキルごとの個別 requirements.txt は禁止。スキル固有スクリプトの依存もここに統合する |

### 5.2 スキル直下 `references/scripts/`（業務単位）

複数業務がある場合は業務単位サブフォルダ分割を **推奨**。

推奨例:

| サブフォルダ | 用途 |
|-----------|------|
| `input/` | 入力データ読み取り処理 |
| `output/` | 出力ファイル生成処理 |
| `checks/` | 機械チェック・検証処理 |
| `helpers/` | 共通ヘルパー |

業務が 1 種類のみなら `references/scripts/` 直下にフラットに置いてよい。

### 5.3 厳格な禁止項目

| 禁止 | 理由 |
|-----|------|
| **プラグイン直下に `scripts/` を置く** | `references/scripts/` に集約（ADR-025） |
| **スキル直下に `scripts/` を置く** | 同上 |
| `references/scripts/` の代わりに `knowledge/` `lib/` `bin/` を使う | `scripts/` 固定、命名衝突回避 |
| 拡張子別サブフォルダ（`references/scripts/py/` `references/scripts/sh/` 等） | 業務単位で分けるべき |
| **スキル直下 `references/scripts/` に Python venv 構築・撤去スクリプトを置く** | プラグイン直下 `references/scripts/setup/` に集約（ADR-024） |
| **スキルごとの個別 `requirements.txt` を作る** | プラグイン直下に統合（ADR-024） |
| **md ファイル内に実行スクリプトをインライン記載する** | `references/scripts/{業務単位}/` にファイル化（ADR-025、詳細は [`../scripts-policy.md`](../scripts-policy.md)）|

### 5.4 venv の配置と運用

| ルール | 内容 |
|-------|------|
| venv 実体の作成先 | `<work_dir>/.venv`（セッション作業領域内） |
| venv ライフサイクルスクリプト | プラグイン直下 `references/scripts/setup/` |
| 各スキルの呼び出し方 | `bash "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/setup_venv.sh" -WorkDir "$WorkDir" -RequirementsPath "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/requirements.txt"`  |
| `environment-setup-toolkit` の役割 | プラグイン直下スクリプト呼び出しのオーケストレーション（自前で setup を持たない、ADR-024） |

詳細は [`../scripts-policy.md`](../scripts-policy.md) 節 5 を参照。