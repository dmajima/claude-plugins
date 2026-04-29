# 既存資産 → プラグインへの移管ルール

`.claude/skills/`、`.claude/commands/`、`.claude/agents/`、`.claude/settings.json` 等の既存アイテムをプラグイン構造へ移管する際の詳細ルール。

## 1. 変換マッピング

| 種別 | 変換元 | 変換先（plugin 内） |
|-----|--------|-------------------|
| スキル | `<src>/.claude/skills/{name}/` | `plugins/{plugin}/skills/{name}/`（ディレクトリ全体をコピー） |
| カスタムコマンド | `<src>/.claude/commands/{name}.md` | `plugins/{plugin}/commands/{name}.md` |
| サブエージェント | `<src>/.claude/agents/{name}.md` | `plugins/{plugin}/agents/{name}.md` |
| フック | `<src>/.claude/settings.json` の `hooks` セクション | `plugins/{plugin}/hooks/hooks.json`（該当部分のみ抽出） |

`<src>` はプロジェクトリポジトリまたは `~`（グローバル）。

## 2. アイテム所在の標準パス

| 種別 | プロジェクト | グローバル |
|-----|-----------|----------|
| スキル | `<repo>/.claude/skills/{name}/SKILL.md` | `~/.claude/skills/{name}/SKILL.md` |
| カスタムコマンド | `<repo>/.claude/commands/{name}.md` | `~/.claude/commands/{name}.md` |
| サブエージェント | `<repo>/.claude/agents/{name}.md` | `~/.claude/agents/{name}.md` |
| フック | `<repo>/.claude/settings.json` の `hooks` | `~/.claude/settings.json` の `hooks` |

## 3. 移管の原則

| 原則 | 内容 |
|-----|------|
| コピー基本 | 元ファイルは無傷（移動はユーザ明示指示時のみ） |
| 構造維持 | スキル内部の `references/` `scripts/` `agents/` 等もそのままコピー |
| パスチェック | コピー後ファイルを Grep で検証、`.claude/skills/{name}/` 等のハードコードは `${CLAUDE_SKILL_DIR}` に置換提案 |
| 依存確認 | スキルが他スキル/外部スクリプトに依存していないか確認 |
| 上書き禁止 | 同名ファイルが配置先に既存する場合は必ずユーザ確認 |
| エンコーディング維持 | UTF-8 以外のファイルは Python 経由で書き戻す |
| `agents/` 保持 | スキル内 `agents/` がグローバル重複でも削除しない |

## 4. 種別別の手順

### 4.1 スキルの移管

| ステップ | 動作 |
|---------|------|
| 1 | 変換元ディレクトリ全体を変換先にコピー |
| 2 | `SKILL.md` の frontmatter `name` がディレクトリ名と一致するか確認 |
| 3 | ハードコード絶対パスを Grep（[`../../../references/path-portability.md`](../../../references/path-portability.md)） |
| 4 | `README.md` 有無確認（無ければ警告し `readme-creator` 接続を提案） |
| 5 | `scripts/` の実行可能性確認（Python 利用時 `setup_venv.sh` 等の存在） |
| 6 | `agents/` `evals/` のサブディレクトリ保持を確認 |

### 4.2 コマンドの移管

| ステップ | 動作 |
|---------|------|
| 1 | ファイルをコピー |
| 2 | frontmatter `description` 有無確認（無ければ追加提案） |
| 3 | プロンプト内のパス参照を確認（`.claude/...` ハードコードがあれば `${CLAUDE_PLUGIN_ROOT}` に書き換え） |

### 4.3 フックの移管

`settings.json` の `hooks` には複数フックが混在しうるため **該当部分のみ抽出** する。

| ステップ | 動作 |
|---------|------|
| 1 | 変換元 `settings.json` を Read |
| 2 | ユーザに「どのフックを移管するか」を確認（イベント名 + matcher で識別） |
| 3 | 該当エントリを抜き出して `plugins/{plugin}/hooks/hooks.json` に Write |
| 4 | 元 `settings.json` には手を加えない（プラグイン化したフックの扱いはユーザ判断） |
| 5 | 移管したフック内のコマンドが `${CLAUDE_PLUGIN_ROOT}` を使うように書き換え |

### 4.4 サブエージェントの移管

| ステップ | 動作 |
|---------|------|
| 1 | ファイルをコピー |
| 2 | frontmatter `name` `description` `tools` を確認 |
| 3 | プロンプト内のパス参照を確認 |

## 5. 移管後の検証チェックリスト

- [ ] プラグイン側のファイル一覧をユーザに提示した
- [ ] パスポータビリティチェックを実施した
- [ ] 変換元ファイルは無傷である
- [ ] frontmatter が valid（YAML パース可能）
- [ ] JSON ファイルが valid
- [ ] 既存ファイルを誤上書きしていない

## 6. 禁止事項

- 変換元ファイルの破壊的編集
- 変換元 `settings.json` の改変
- 同名既存ファイルの無確認上書き
- 巨大スキルの自動分割（ユーザ指示なき限り原型維持）
- スキル内 `agents/` の重複削除
