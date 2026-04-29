# 命名・配置・構造規約（SSOT）

`extension-creator` プラグイン配下の全スキルが従うべき命名・配置・構造規約。

## 1. 命名規約

| 対象 | 形式 | 例 |
|-----|------|---|
| プラグイン名 | kebab-case | `extension-creator` |
| スキル名 | kebab-case（`SKILL.md` の `name` と一致） | `skill-creator` |
| コマンド名 | kebab-case（拡張子 `.md` を除く） | `extension` |
| エージェント名 | kebab-case | `code-reviewer` |
| エージェントチーム名 | kebab-case | `system-design` |
| フックファイル | `hooks.json` 固定 | `hooks/hooks.json` |
| テンプレートディレクトリ | 種別を表す英単語 | `templates/skill/` |

## 2. プラグインの標準ディレクトリ構造

```
plugins/{plugin-name}/
├── .claude-plugin/
│   └── plugin.json                 # 必須
├── README.md                        # 必須（人間向け）
├── commands/                        # 任意
│   └── {command-name}.md
├── skills/                          # 任意
│   └── {skill-name}/
│       ├── SKILL.md                 # 必須
│       ├── README.md                # 必須
│       ├── references/              # 任意
│       ├── scripts/                 # 任意（業務単位サブフォルダ必須）
│       │   └── setup/               # Python 利用時の必須セット
│       │       ├── requirements.txt
│       │       ├── setup_venv.sh
│       │       └── teardown_venv.sh
│       ├── agents/                  # 任意（プラグイン配布時はグローバル重複でも保持）
│       └── evals/                   # 動作分岐ありなら必須
├── agents/                          # 任意
│   └── {agent-name}.md
├── hooks/                           # 任意
│   └── hooks.json
└── mcp/                             # 任意
    └── ...
```

## 3. スキル内構造規約

### 3.1 SKILL.md

| 制約 | 値 |
|-----|---|
| 行数上限 | 200 行 |
| 必須フィールド | `name` `description`（frontmatter） |
| 内容 | 概要・トリガー条件・基本フロー概要のみ |
| 詳細記述場所 | `references/` 配下に分離 |

### 3.2 references/ 配下

業務単位ごとにサブフォルダ分割。例:

```
references/
├── setup.md             # 環境構築（Python venv 等）
├── procedures.md        # 実行手順（冒頭で setup.md を参照）
├── rules.md             # 詳細ルール
└── template/            # スキルが生成するテンプレート
    └── ...
```

### 3.3 scripts/ 配下

| ルール | 内容 |
|-------|------|
| フォルダ名 | `scripts/`（`knowledge/` 不可） |
| 業務単位サブフォルダ | 必須（複数業務がある場合） |
| 拡張子分類 | 禁止 |
| Python 利用時 | `scripts/setup/` に `requirements.txt` `setup_venv.sh` `teardown_venv.sh` |
| venv の作成先 | `<work_dir>/.venv`（`scripts/` 内ではない） |

### 3.4 agents/ 配下

スキルが内部でサブエージェントを起動する場合に配置。**グローバル `~/.claude/agents/` と重複していても削除しない**（プラグイン配布先環境にグローバルがない可能性があるため）。

### 3.5 evals/ 配下

動作分岐があるスキルは必須。詳細は [eval-guide.md](eval-guide.md) を参照。

## 4. コマンドファイル構造

```markdown
---
description: コマンドの 1 行説明
---

実行内容のプロンプト。$ARGUMENTS でユーザ引数を受け取る。
```

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
## 評価観点
## 出力フォーマット
## プロンプトテンプレート
```

## 6. テンプレートの配置

スキルが生成するテンプレートは **2 階層** で管理する。

| 階層 | 配置場所 | 用途 |
|-----|---------|------|
| プラグイン横断 | `plugins/extension-creator/templates/{種別}/` | 全スキル共通の推奨構成 |
| スキル固有 | `plugins/extension-creator/skills/{skill-name}/references/template/` | そのスキルが生成する固有のテンプレート |

スキル固有の派生は **プラグイン横断テンプレートをコピー** してから差分を加える方針。

## 7. パスポータビリティ

詳細は [path-portability.md](path-portability.md) を参照。

| 用途 | 変数 |
|-----|------|
| スキル自身のディレクトリ | `${CLAUDE_SKILL_DIR}` |
| プラグイン自身のルート | `${CLAUDE_PLUGIN_ROOT}` |
| プラグインの永続データ領域 | `${CLAUDE_PLUGIN_DATA}` |

ローカル絶対パス（Windows ドライブレター・ユーザディレクトリ・UNC）の **ハードコード禁止**。

## 8. ファイル編集時のエンコーディング

既存ファイル更新時は **元ファイルのエンコーディング・改行コードを維持する**。詳細は `~/.claude/rules/common/file-encoding.md` を参照。

UTF-8 以外（Shift-JIS / CP932 等）のファイルは Edit / Write ツールを直接使用せず、Python 経由で書き戻す。

## 9. README.md ポリシー

- 人間向けリファレンス（Claude スキル動作では不参照）
- **常に最新版のみ記載**。過去履歴は記載しない（Git 管理のため不要）
- `SKILL.md` / `references/` は README.md を参照しない（一方向参照）

## 10. 禁止事項

- `SKILL.md` 200 行超過
- `scripts/` 命名の差し替え（`knowledge/` 等）
- `agents/` の重複削除
- ローカル絶対パスのハードコード
- README.md への過去履歴・変更経緯の記載
- 動作分岐がある場合の evals 省略
- `§` 記号の使用（代替: `1.` / `セクション1` / `第1節` 等）
