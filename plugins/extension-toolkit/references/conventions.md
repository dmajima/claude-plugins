# 命名・配置・構造規約（SSOT）

`extension-toolkit` プラグイン配下の全スキル・全成果物が従うべき命名・配置・構造規約。

階層別の厳格度:

| 階層 | 厳格度 | 内容 |
|-----|-------|------|
| プラグイン直下 | **厳格（許可リスト運用）** | 列挙されたディレクトリ・ファイル以外を置かない |
| スキル直下 | **厳格（許可リスト運用）** | 同上 |
| `references/` 直下 | 推奨例（緩い） | 推奨される命名・配置を例示。実情に応じて拡張可 |
| `scripts/` 直下 | 推奨例（緩い） | 推奨される業務単位サブフォルダを例示。`knowledge/` 等の禁止項目のみ厳格 |

## 1. 命名規約

| 対象 | 形式 | 例 |
|-----|------|---|
| プラグイン名 | kebab-case | `extension-toolkit` |
| スキル名 | kebab-case（`SKILL.md` の `name` と一致） | `skill-toolkit` |
| コマンド名 | kebab-case（拡張子 `.md` を除く） | `extension` |
| エージェント名 | kebab-case | `code-reviewer` |
| エージェントチーム名 | kebab-case | `skill-review-team` |
| フックファイル | `hooks.json` 固定 | `hooks/hooks.json` |
| references 配下のドキュメント | kebab-case + 用途名 | `references/conventions.md` |
| evals ケースファイル | `case-{2 桁番号}_{snake_case 名}.md` | `case-01_new_skill_interactive.md` |

禁止される命名:

| 禁止 | 理由 | 代替 |
|-----|------|------|
| `knowledge/`（スクリプト保管用） | 規約違反 | `scripts/` |
| `shared/`（プラグイン横断 SSOT） | 規約違反 | `references/` |
| CamelCase / snake_case のディレクトリ名 | エコシステム慣用に反する | kebab-case |
| `§` 記号を含むファイル名・本文 | 文書ルール違反 | `1.` / `セクション1` / `第1節` |

## 2. プラグイン直下の構造（**厳格運用**）

### 2.1 許可されるエントリ（完全列挙、これ以外禁止）

```text
plugins/{plugin-name}/
├── .claude-plugin/                # 必須（Claude Code 公式仕様）
│   └── plugin.json                # 必須
├── README.md                      # 必須（人間向けリファレンス、readme-policy.md 準拠）
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
└── references/                    # 任意（独自、SSOT・チーム定義・テンプレート集約。節 4 で詳述）
    └── ...
```

### 2.2 許可リストの根拠

| エントリ | 由来 | 必須/任意 |
|---------|------|----------|
| `.claude-plugin/plugin.json` | Claude Code 公式 | 必須 |
| `README.md` | 独自ルール（[`readme-policy.md`](readme-policy.md)） | 必須 |
| `commands/` | Claude Code 公式 | 任意 |
| `skills/` | Claude Code 公式 | 任意 |
| `agents/` | Claude Code 公式 | 任意 |
| `hooks/` | Claude Code 公式 | 任意 |
| `mcp/` | Claude Code 公式 | 任意 |
| `references/` | 独自（SSOT 集約） | 任意 |

### 2.3 配置の禁止

| 禁止 | 理由 |
|-----|------|
| プラグイン直下に `teams/` を置く | 独自構造は `references/` 配下に集約（ADR-002） |
| プラグイン直下に `templates/` を置く | 同上 |
| プラグイン直下に `shared/` `common/` `lib/` 等を置く | `references/` を使う |
| プラグイン直下にトップレベル `scripts/` を置く | スキル内 `scripts/` または `environment-setup-toolkit` を使う |
| プラグイン直下に `docs/` を置く | `README.md` + `references/` で完結させる |
| Claude Code 公式 + `references/` 以外のトップレベルディレクトリを追加 | ADR で明示する場合のみ例外 |

### 2.4 例外条項

許可リスト外のディレクトリ・ファイルを追加する場合:

| 手順 | 内容 |
|-----|------|
| 1 | [`architecture-decisions.md`](architecture-decisions.md) に新 ADR を追加（決定 / 理由 / トレードオフ / 代替案を必須記載） |
| 2 | 本ファイル節 2.1 の許可リストを更新 |
| 3 | [`validation-rules.md`](validation-rules.md) の機械チェックを更新 |

ADR 追加なしの追加は **規約違反**。

## 3. スキル直下の構造（**厳格運用**）

### 3.1 許可されるエントリ（完全列挙、これ以外禁止）

```text
plugins/{plugin-name}/skills/{skill-name}/
├── SKILL.md                       # 必須（Claude Code 公式仕様）
├── README.md                      # 必須（独自、readme-policy.md 準拠）
├── references/                    # 任意（スキル固有の詳細ドキュメント）
├── scripts/                       # 任意（実行可能スクリプト、節 5 で詳述）
├── agents/                        # 任意（Claude Code 公式仕様、グローバル重複でも保持）
└── evals/                         # 動作分岐ありなら必須（独自）
```

### 3.2 許可リストの根拠

| エントリ | 由来 | 必須/任意 |
|---------|------|----------|
| `SKILL.md` | Claude Code 公式 | 必須 |
| `README.md` | 独自ルール（[`readme-policy.md`](readme-policy.md)） | 必須 |
| `references/` | 独自（スキル固有の詳細） | 任意 |
| `scripts/` | 独自（実行可能スクリプト） | 任意 |
| `agents/` | Claude Code 公式（プラグイン配布時のサブエージェント） | 任意 |
| `evals/` | 独自（[`eval-guide.md`](eval-guide.md)） | 動作分岐ありなら必須 |

### 3.3 配置の禁止

| 禁止 | 理由 |
|-----|------|
| `scripts/` の代わりに `knowledge/` `lib/` `bin/` 等 | `scripts/` 固定（命名衝突回避） |
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

`references/` 直下は **プラグイン横断 SSOT・チーム定義・推奨構成テンプレート** を集約する場。実情に応じて拡張可（厳格な許可リストではない）。

推奨例:

```text
plugins/{plugin-name}/references/
├── conventions.md                 # 命名・配置・構造規約（本ファイル）
├── ai-readability.md              # AI 誤認回避ライティング規約
├── description-guide.md           # description 設計ガイド
├── path-portability.md            # ポータブルパス規約
├── eval-guide.md                  # evals 作成ガイド
├── validation-rules.md            # 検証ルール SSOT
├── architecture-decisions.md      # ADR
├── versioning.md                  # バージョン管理ルール
├── completion-checklist.md        # 作業完了前チェックリスト
├── user-interaction.md            # ユーザ対話ルール
├── state-files.md                 # 状態ファイル形式
├── readme-policy.md               # README 規約
├── agent-utilization.md           # エージェント活用方針
├── dependencies-policy.md         # 外部プラグイン依存ルール
├── teams/                         # エージェントチーム定義
│   └── {team-name}.md
└── templates/                     # 推奨構成テンプレート
    ├── skill/
    ├── plugin/
    ├── command/
    ├── agent/
    ├── hook/
    └── readme/
```

### 4.2 references/ 直下の運用ルール（緩い）

| 観点 | ルール |
|-----|------|
| ファイル分割粒度 | 業務単位ごと（命名・規約・ガイド・テンプレート等） |
| 命名 | kebab-case + 用途名 |
| サブディレクトリの追加 | プラグインの規模・性質に応じて自由（厳格な制限なし） |
| `teams/` `templates/` の配置 | references/ 配下を推奨（プラグイン直下には置かない、ADR-002） |

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

## 5. scripts/ 直下の構造（**推奨例 + 一部禁止項目**）

### 5.1 推奨される業務単位サブフォルダ

複数業務がある場合は業務単位サブフォルダ分割を **推奨**。

推奨例:

| サブフォルダ | 用途 |
|-----------|------|
| `setup/` | 環境構築（venv 関連はここに置かない、`environment-setup-toolkit` に委譲） |
| `input/` | 入力データ読み取り処理 |
| `output/` | 出力ファイル生成処理 |
| `deps/` | 依存リスト保管（`requirements.txt` 等） |
| `helpers/` | 共通ヘルパー |

業務が 1 種類のみなら `scripts/` 直下にフラットに置いてよい。

### 5.2 厳格な禁止項目

業務単位サブフォルダ自体は推奨だが、以下は **厳格に禁止**:

| 禁止 | 理由 |
|-----|------|
| `scripts/` の代わりに `knowledge/` `lib/` `bin/` を使う | `scripts/` 固定、命名衝突回避 |
| 拡張子別サブフォルダ（`scripts/py/` `scripts/sh/` 等） | 業務単位で分けるべき |
| Python venv 構築・撤去スクリプトをスキル内に置く | `environment-setup-toolkit` に委譲（ADR-010） |

### 5.3 venv の配置

| ルール | 内容 |
|-------|------|
| venv 作成先 | `<work_dir>/.venv`（`scripts/` 内ではない） |
| venv 構築・撤去 | `environment-setup-toolkit` に委譲 |
| 依存リスト保管 | `scripts/deps/requirements.txt` または `references/setup.md` |

## 6. コマンドファイル構造

```markdown
---
description: コマンドの 1 行説明（60 文字以内）
---

実行内容のプロンプト。$ARGUMENTS でユーザ引数を受け取る。
```

| ルール | 内容 |
|-------|------|
| frontmatter `description` | 60 文字以内 |
| 引数仕様 | description ではなく本文に書く |

## 7. エージェントファイル構造

```markdown
---
name: {agent-name}
description: いつ使うかの説明
model: sonnet
tools: {許可ツールのカンマ区切りリスト}
---

# {役割名}

## ロール定義
## 専門性
## 評価観点
## 出力フォーマット
## プロンプトテンプレート
```

| 必須セクション | 内容 |
|------------|------|
| ロール定義 | 1〜3 文の役割記述 |
| 専門性 | 専門領域 / 評価軸 / 参照する外部知識 |
| 評価観点 | 3 項目以上のチェックリスト |
| 出力フォーマット | Critical / High / Medium / Low / 総合判定の構造 |
| プロンプトテンプレート | 起動時に渡すプロンプトのひな形 |

## 8. テンプレートの 2 階層管理

| 階層 | 配置 | 用途 |
|-----|-----|------|
| プラグイン横断 | `plugins/{plugin}/references/templates/{種別}/` | 全スキル共通の推奨構成 |
| スキル固有 | `plugins/{plugin}/skills/{skill}/references/template/` | そのスキルが生成する固有テンプレート |

スキル固有派生は **横断テンプレートをコピーしてから差分** を加える（ADR-003）。

## 9. パスポータビリティ

詳細は [`path-portability.md`](path-portability.md) を参照。

| 用途 | 変数 |
|-----|------|
| スキル自身のディレクトリ | `${CLAUDE_SKILL_DIR}` |
| プラグイン自身のルート | `${CLAUDE_PLUGIN_ROOT}` |
| プラグインの永続データ領域 | `${CLAUDE_PLUGIN_DATA}` |

ローカル絶対パスのハードコード禁止。

## 10. ファイル編集時のエンコーディング

既存ファイル更新時は **元ファイルのエンコーディング・改行コードを維持** する（文字化け防止）。詳細は `~/.claude/rules/common/file-encoding.md` を参照。

UTF-8 以外（Shift-JIS / CP932 等）のファイルは Edit / Write ツールを直接使用せず、Python 経由で書き戻す。

## 11. README.md ポリシー

詳細は [`readme-policy.md`](readme-policy.md) を参照。

- **すべてのプラグイン・スキルに必須**
- 人間向けリファレンス（Claude スキル動作では不参照）
- **常に最新版のみ記載**（過去履歴は Git 管理のため不要）
- 利用者向け導入手順を冒頭、技術スタック・アーキテクチャは後半
- `SKILL.md` / `references/` は `README.md` を参照しない（一方向参照）

## 12. 禁止事項（厳格・緩和を区別）

### 12.1 厳格な禁止（配置）

- プラグイン直下のディレクトリで節 2.1 に列挙されていないものを追加（ADR で明示する場合のみ例外）
- スキル直下に節 3.1 に列挙されていないディレクトリ・ファイルを置く（ADR で明示する場合のみ例外）

### 12.2 厳格な禁止（命名）

- `scripts/` の代わりに `knowledge/` `lib/` `bin/` 等を使用
- `references/` の代わりに `shared/` `common/` `docs/` 等を使用
- 拡張子別のサブフォルダ（`scripts/py/` `scripts/sh/` 等）

### 12.3 厳格な禁止（ファイル内容）

- `SKILL.md` 200 行超過（超過時は references に分離する）
- `agents/` ディレクトリの重複理由による削除（プラグイン配布先環境のため保持必須）
- ローカル絶対パスのハードコード（`${CLAUDE_*}` または相対パスを使う）
- `README.md` への過去履歴・変更経緯の記載（Git 管理のため不要）
- 動作分岐があるスキルでの `evals/` 省略
- `§` 記号の使用（代替: `1.` / `セクション1` / `第1節` 等）
- 構造化データの Markdown 表での長期保存（[`state-files.md`](state-files.md) 参照）

### 12.4 厳格な禁止（操作）

- 既存ファイル更新時のエンコーディング・改行コード変更
- ユーザ選択を AskUserQuestion 以外の方法で求める（重要な選択肢の場合）
- 作業完了報告前に [`completion-checklist.md`](completion-checklist.md) の自己検証を省略

### 12.5 厳格な禁止（ドキュメント履歴記載）

- プラグイン内ドキュメント（README / SKILL.md / references / evals 等）に自身の更新履歴を残すこと（[ADR-016](architecture-decisions.md) 参照）
- 「当初は」「改訂」「Round-N で」「リネーム時点で」のような時系列記述
- 「## 変更履歴」「## Changelog」「## Release Notes」等のセクション
- 例外: ユーザから明示指示があった場合のみ履歴記載を許容

## 13. 検証

本規約のうち **節 2.1（プラグイン直下）と節 3.1（スキル直下）の許可リスト遵守** は [`validation-rules.md`](validation-rules.md) の機械チェックで自動検出する。`references/` 直下と `scripts/` 直下は推奨例のため機械チェック対象外（人間レビューで確認）。
