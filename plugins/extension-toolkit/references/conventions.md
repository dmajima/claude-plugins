# 命名・配置・構造規約（SSOT）

`extension-toolkit` プラグイン配下の全スキル・全成果物が従うべき命名・配置・構造規約。**列挙されたディレクトリ以外は許可しない**（厳格運用）。

## 1. 命名規約

| 対象 | 形式 | 例 |
|-----|------|---|
| プラグイン名 | kebab-case | `extension-toolkit` |
| スキル名 | kebab-case（`SKILL.md` の `name` と一致） | `skill-toolkit` |
| コマンド名 | kebab-case（拡張子 `.md` を除く） | `extension` |
| エージェント名 | kebab-case | `code-reviewer` |
| エージェントチーム名 | kebab-case | `skill-review-team` |
| フックファイル | `hooks.json` 固定 | `hooks/hooks.json` |
| テンプレート種別ディレクトリ | 種別を表す英単語（kebab-case） | `references/templates/skill/` |
| references 配下のドキュメント | kebab-case + 用途名 | `references/conventions.md` |
| evals ケースファイル | `case-{2 桁番号}_{snake_case 名}.md` | `case-01_new_skill_interactive.md` |

禁止される命名:

| 禁止 | 理由 | 代替 |
|-----|------|------|
| `knowledge/`（スクリプト保管用） | 過去指摘で却下 | `scripts/` |
| `shared/`（プラグイン横断 SSOT） | 過去指摘で却下 | `references/` |
| CamelCase / snake_case のディレクトリ名 | エコシステム慣用に反する | kebab-case |
| `§` 記号を含むファイル名・本文 | 文書ルール違反 | `1.` / `セクション1` / `第1節` |

## 2. プラグインの標準ディレクトリ構造（厳格運用）

### 2.1 プラグイン直下に許可されるエントリ（完全列挙）

```text
plugins/{plugin-name}/
├── .claude-plugin/                # 必須（Claude Code 公式仕様）
│   └── plugin.json                # 必須
├── README.md                      # 必須（人間向けリファレンス、readme-policy.md 準拠）
├── commands/                      # 任意（Claude Code 公式仕様）
│   └── {command-name}.md
├── skills/                        # 任意（Claude Code 公式仕様）
│   └── {skill-name}/
│       └── ...                    # 詳細は節 3
├── agents/                        # 任意（Claude Code 公式仕様）
│   └── {agent-name}.md
├── hooks/                         # 任意（Claude Code 公式仕様）
│   └── hooks.json
├── mcp/                           # 任意（Claude Code 公式仕様）
│   └── ...
└── references/                    # 任意（独自、SSOT）
    └── ...                        # 詳細は節 2.2
```

| エントリ | 必須/任意 | 由来 |
|---------|----------|------|
| `.claude-plugin/plugin.json` | 必須 | Claude Code 公式 |
| `README.md` | 必須 | 独自ルール（[`readme-policy.md`](readme-policy.md)） |
| `commands/` | 任意 | Claude Code 公式 |
| `skills/` | 任意 | Claude Code 公式 |
| `agents/` | 任意 | Claude Code 公式（プラグイン配布時のサブエージェント） |
| `hooks/` | 任意 | Claude Code 公式 |
| `mcp/` | 任意 | Claude Code 公式 |
| `references/` | 任意 | 独自（プラグイン横断 SSOT） |

**上記以外のディレクトリ・ファイルをプラグイン直下に置いてはならない**。例外は ADR で明示する。

### 2.2 references/ 配下に許可されるエントリ（完全列挙）

```text
plugins/{plugin-name}/references/
├── conventions.md                 # 命名・配置・構造規約（本ファイル）
├── ai-readability.md              # AI 誤認回避ライティング規約
├── description-guide.md           # description 設計ガイド
├── path-portability.md            # ポータブルパス規約
├── eval-guide.md                  # evals 作成ガイド
├── validation-rules.md            # 検証ルール SSOT
├── architecture-decisions.md      # ADR（アーキテクチャ決定記録）
├── versioning.md                  # バージョン管理ルール
├── completion-checklist.md        # 作業完了前チェックリスト
├── user-interaction.md            # ユーザ対話（AskUserQuestion 優先）
├── state-files.md                 # 状態ファイル形式
├── readme-policy.md               # README 規約
├── agent-utilization.md           # エージェント活用方針
├── dependencies-policy.md         # 外部プラグイン依存ルール
├── teams/                         # エージェントチーム定義（独自）
│   └── {team-name}.md
└── templates/                     # 推奨構成テンプレート（独自）
    ├── skill/
    ├── plugin/
    ├── command/
    ├── agent/
    ├── hook/
    └── readme/
```

| 種別 | 配置場所 | 役割 |
|-----|---------|------|
| ガイドライン MD | `references/` 直下 | プラグイン横断のルール SSOT |
| エージェントチーム定義 | `references/teams/{name}.md` | 独自（Claude Code 公式仕様の `agents/` とは別） |
| 推奨構成テンプレート | `references/templates/{種別}/` | 独自 |

**`references/` 配下に上記以外のサブディレクトリを作る場合は ADR で明示する**。

### 2.3 配置の禁止事項

| 禁止 | 理由 |
|-----|------|
| プラグイン直下に `teams/` を置く | 独自構造は `references/` 配下に集約（ADR-002） |
| プラグイン直下に `templates/` を置く | 同上 |
| プラグイン直下に `shared/` `common/` `lib/` 等を置く | `references/` を使う |
| プラグイン直下にトップレベル `scripts/` を置く | スキル内 `scripts/` または `environment-setup-toolkit` 配下を使う（責務単一化） |
| プラグイン直下に `docs/` を置く | `README.md` + `references/` で完結させる |

## 3. スキル内構造規約（厳格運用）

### 3.1 スキル直下に許可されるエントリ（完全列挙）

```text
plugins/{plugin-name}/skills/{skill-name}/
├── SKILL.md                       # 必須
├── README.md                      # 必須（人間向け）
├── references/                    # 任意（スキル固有の詳細ドキュメント）
├── scripts/                       # 任意（業務単位サブフォルダ必須、節 3.3）
├── agents/                        # 任意（プラグイン配布時はグローバル重複でも保持、節 3.4）
└── evals/                         # 動作分岐ありなら必須（節 3.5）
```

| エントリ | 必須/任意 | 由来 |
|---------|----------|------|
| `SKILL.md` | 必須 | Claude Code 公式 |
| `README.md` | 必須 | 独自ルール（[`readme-policy.md`](readme-policy.md)） |
| `references/` | 任意 | 独自（スキル固有の詳細） |
| `scripts/` | 任意 | 独自（実行可能スクリプト） |
| `agents/` | 任意 | Claude Code 公式 |
| `evals/` | 動作分岐ありなら必須 | 独自（[`eval-guide.md`](eval-guide.md)） |

スキル直下に上記以外のディレクトリ・ファイルを置いてはならない。

### 3.2 SKILL.md

| 制約 | 値 |
|-----|---|
| 行数上限 | 200 行 |
| 必須フィールド | `name` `description`（frontmatter） |
| `name` の一致 | ディレクトリ名と完全一致 |
| 必須セクション | 責務 / 責務外 / トリガー条件 / 前提 / 実行モード判定 / 実行フロー / 重要な制約 / 参照 |
| 内容粒度 | 概要・トリガー条件・基本フロー概要のみ（詳細は references に分離） |

### 3.3 references/ 配下（スキル内）

スキル固有の詳細ドキュメントを業務単位サブファイルで分割する。

```text
references/
├── procedures.md         # 実行手順詳細（推奨）
├── setup.md              # 環境構築手順（Python 利用時、environment-setup-toolkit への委譲記述）
├── rules.md              # 詳細ルール（必要時）
├── {topic}.md            # その他、業務単位ごと
└── template/             # スキル固有テンプレート（任意、references/templates/ をコピーして派生）
    └── ...
```

| ルール | 内容 |
|-------|------|
| ファイル分割粒度 | 業務単位ごと（procedures / setup / rules 等） |
| 命名 | kebab-case + 用途名 |
| `template/`（スキル内固有） | 任意。プラグイン横断 `references/templates/` をコピーして派生する用途のみ |

### 3.4 scripts/ 配下（厳格運用）

| ルール | 内容 |
|-------|------|
| フォルダ名 | `scripts/` 固定（`knowledge/` `lib/` `bin/` 等は禁止） |
| 業務単位サブフォルダ | **複数業務がある場合は必須**（例: `setup/` `input/` `output/` `deps/`） |
| 拡張子分類 | **禁止**（`py/` `sh/` 等のサブフォルダで分けない。業務で分ける） |
| Python 利用時の依存リスト | `scripts/deps/requirements.txt` または `references/setup.md` に保管 |
| Python venv 構築・撤去スクリプト | **スキル内に置かない**（`environment-setup-toolkit` に委譲、ADR-010） |
| venv の作成先 | `<work_dir>/.venv`（`scripts/` 内ではない） |

業務単位サブフォルダの命名例:

| サブフォルダ | 用途 |
|-----------|------|
| `setup/` | 環境構築（venv 関連はここに置かない） |
| `input/` | 入力データ読み取り処理 |
| `output/` | 出力ファイル生成処理 |
| `deps/` | 依存リスト保管（`requirements.txt` 等） |
| `helpers/` | 共通ヘルパー |

### 3.5 agents/ 配下（スキル内）

スキルが内部でサブエージェントを起動する場合に配置する。

| ルール | 内容 |
|-------|------|
| 命名 | `{agent-name}.md`（kebab-case） |
| グローバル重複 | **削除禁止**（プラグイン配布先環境にグローバルがない可能性、過去指摘） |
| frontmatter | `name` `description` `model` `tools` 必須 |

### 3.6 evals/ 配下

動作分岐があるスキルは必須。詳細は [`eval-guide.md`](eval-guide.md) を参照。

```text
evals/
├── README.md                      # ケース一覧、追加ルール
├── case-01_{snake_case 名}.md
├── case-02_{snake_case 名}.md
└── ...
```

| ルール | 内容 |
|-------|------|
| ケースファイル命名 | `case-{2 桁番号}_{snake_case}.md` |
| README.md | 必須（ケース一覧 + 追加ルール記載） |
| 1 ケース 1 ファイル | 複数ケース混在禁止 |
| カバレッジ | 主要分岐 / 対話 ✕ 非対話 / エラー系の網羅 |

## 4. コマンドファイル構造

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

## 5. エージェントファイル構造

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

## 6. テンプレートの 2 階層管理

| 階層 | 配置 | 用途 | 編集影響 |
|-----|-----|------|---------|
| プラグイン横断 | `plugins/{plugin}/references/templates/{種別}/` | 全スキル共通の推奨構成 | 全スキルへ波及（慎重に変更） |
| スキル固有 | `plugins/{plugin}/skills/{skill}/references/template/` | そのスキルが生成する固有テンプレート | 当該スキルのみ |

スキル固有派生は **横断テンプレートをコピーしてから差分** を加える。横断テンプレートを変更する場合は派生派の整合性を再確認する。

## 7. パスポータビリティ

詳細は [`path-portability.md`](path-portability.md) を参照。

| 用途 | 変数 | 解決タイミング |
|-----|------|------------|
| スキル自身のディレクトリ | `${CLAUDE_SKILL_DIR}` | スキル実行時に Claude Code が解決 |
| プラグイン自身のルート | `${CLAUDE_PLUGIN_ROOT}` | プラグイン由来のスキル/コマンド/フック実行時に解決 |
| プラグインの永続データ領域 | `${CLAUDE_PLUGIN_DATA}` | プラグイン実行時に解決 |

ローカル絶対パス（Windows ドライブレター・ユーザディレクトリ・UNC）の **ハードコード禁止**。

## 8. ファイル編集時のエンコーディング

既存ファイル更新時は **元ファイルのエンコーディング・改行コードを維持する**。詳細は `~/.claude/rules/common/file-encoding.md` を参照。

UTF-8 以外（Shift-JIS / CP932 等）のファイルは Edit / Write ツールを直接使用せず、Python 経由で書き戻す。

## 9. README.md ポリシー

詳細は [`readme-policy.md`](readme-policy.md) を参照。

- **すべてのプラグイン・スキルに必須**
- 人間向けリファレンス（Claude スキル動作では不参照）
- **常に最新版のみ記載**（過去履歴は Git 管理のため不要）
- 利用者向け導入手順を冒頭、技術スタック・アーキテクチャは後半
- `SKILL.md` / `references/` は `README.md` を参照しない（一方向参照）

## 10. 禁止事項（完全リスト）

### 10.1 命名・配置の禁止

- プラグイン直下のディレクトリで節 2.1 に列挙されていないものを追加（ADR で明示する場合のみ例外）
- `references/` 配下のサブディレクトリで節 2.2 に列挙されていないものを追加（ADR で明示する場合のみ例外）
- スキル直下に節 3.1 に列挙されていないディレクトリ・ファイルを置く
- `scripts/` の代わりに `knowledge/` `lib/` `bin/` 等を使用
- `references/` の代わりに `shared/` `common/` `docs/` 等を使用
- 拡張子別のサブフォルダ（`scripts/py/` `scripts/sh/` 等）

### 10.2 ファイル内容の禁止

- `SKILL.md` 200 行超過（超過時は references に分離する）
- `agents/` ディレクトリの重複理由による削除（プラグイン配布先環境のため保持必須）
- ローカル絶対パスのハードコード（`${CLAUDE_*}` または相対パスを使う）
- `README.md` への過去履歴・変更経緯の記載（Git 管理のため不要）
- 動作分岐があるスキルでの `evals/` 省略
- `§` 記号の使用（代替: `1.` / `セクション1` / `第1節` 等）
- 構造化データの Markdown 表での長期保存（[`state-files.md`](state-files.md) 参照）

### 10.3 操作の禁止

- 既存ファイル更新時のエンコーディング・改行コード変更（[`state-files.md`](state-files.md) / `~/.claude/rules/common/file-encoding.md` 参照）
- ユーザ選択を AskUserQuestion 以外の方法で求める（重要な選択肢の場合、[`user-interaction.md`](user-interaction.md) 参照）
- 作業完了報告前に [`completion-checklist.md`](completion-checklist.md) の自己検証を省略

## 11. 例外条項の運用

節 2.1 / 2.2 / 3.1 の許可リストを超えるディレクトリ・ファイルを追加する場合:

| 手順 | 内容 |
|-----|------|
| 1 | [`architecture-decisions.md`](architecture-decisions.md) に新 ADR を追加（決定 / 理由 / トレードオフ / 代替案を必須記載） |
| 2 | 本ファイル（conventions.md）の許可リストに追記（節 2.1 / 2.2 / 3.1 のいずれか） |
| 3 | 関連する SSOT（`validation-rules.md` 等）の機械チェックを更新 |

ADR / 規約更新なしの追加は **規約違反** として扱う。

## 12. 検証

本規約の遵守は [`validation-rules.md`](validation-rules.md) の機械チェックで自動検出する。新規ディレクトリ・ファイル追加時は許可リストとの照合を必ず行う。
