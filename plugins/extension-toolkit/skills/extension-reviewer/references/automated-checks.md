# 機械的チェック項目

`extension-reviewer` が並列で実施する機械的チェックの一覧と実行方法。

## チェック項目一覧

| 項目 | 対象 | 方法 | 違反時の重大度 |
|-----|-----|------|--------------|
| SKILL.md 200 行制約 | 各 `SKILL.md` | `wc -l` | High |
| パスポータビリティ | 全テキストファイル | Grep（NG パターン） | Critical or High |
| プレースホルダ残存 | 全テキストファイル | Grep `\{[a-z-]+\}` | High |
| frontmatter valid | `*.md` の frontmatter | YAML パース | High |
| JSON valid | `*.json` | JSON パース | Critical |
| `§` 記号 | 全テキストファイル | Grep `§` | Medium |
| 必須セクション存在 | `SKILL.md` | パターン検索 | High |
| description 文字数 | frontmatter `description` | 文字数カウント | Medium |
| `agents/` 削除痕跡 | 既存スキル更新時 | git diff | High |
| エンコーディング保持 | 編集ファイル | バイト列比較 | Critical |

## 実行方法

### 1. 行数チェック（SKILL.md 200 行）

```bash
find {target_dir} -name "SKILL.md" -exec wc -l {} \;
```

200 行超過のファイルを High 指摘として記録。

### 2. パスポータビリティ Grep

```bash
# Windows ドライブレター
grep -rn "[A-Za-z]:[\\/]" {target_dir}

# Unix ユーザディレクトリ
grep -rn "/home/\|/Users/\|/root/" {target_dir}

# Windows 環境変数
grep -rn "%USERPROFILE%\|%APPDATA%\|%LOCALAPPDATA%" {target_dir}

# シェル HOME 変数
grep -rn '\$HOME\|\${HOME}' {target_dir}

# UNC パス
grep -rn '\\\\[A-Za-z0-9._-]\+\\' {target_dir}
```

検出結果を [`../../../references/path-portability.md`](../../../references/path-portability.md) の分類（NG / 例外候補 / OK）に振り分け。

### 3. プレースホルダ残存

```bash
grep -rn '{[a-z][a-z0-9-]*}' {target_dir} --include="*.md" --include="*.json"
```

`{plugin-name}` `{skill-name}` 等のテンプレートプレースホルダが残存していれば High 指摘。

### 4. frontmatter / JSON valid

Python で YAML / JSON パース。エラー時は Critical 指摘。

```python
import yaml, json

# frontmatter
with open(skill_md, 'r', encoding='utf-8') as f:
    content = f.read()
parts = content.split('---', 2)
yaml.safe_load(parts[1])  # 失敗で Critical

# JSON
with open(plugin_json, 'r', encoding='utf-8') as f:
    json.load(f)  # 失敗で Critical
```

### 5. `§` 記号検出

```bash
grep -rn '§' {target_dir}
```

検出時は Medium 指摘 + 代替表現の提案。

### 6. 必須セクション存在チェック

`SKILL.md` に以下のセクションが存在するか確認:

```bash
grep -E '^## (責務|責務外|トリガー条件|前提|実行フロー|重要な制約)' {skill_md}
```

欠落時は High 指摘。

### 7. description 文字数チェック

| 対象 | 目安 |
|-----|-----|
| プラグイン `description` | 80 文字以内 |
| コマンド `description` | 60 文字以内 |
| スキル `description` | 制限なし（むしろ詳細推奨） |
| エージェント `description` | 制限なし |

超過時は Medium 指摘。

### 8. `agents/` 削除痕跡（更新時）

```bash
git diff HEAD -- "*/agents/"
```

スキル内 `agents/` が削除されていたら High 指摘（プラグイン配布のため保持必須）。

### 9. エンコーディング保持

編集前後でバイト列を比較し、文字コード変換が起きていないか確認。

```python
import subprocess

# 編集前のエンコーディング
before = subprocess.run(['file', '--mime-encoding', file_path], capture_output=True).stdout

# 編集後
after = subprocess.run(['file', '--mime-encoding', file_path], capture_output=True).stdout

if before != after:
    # Critical 指摘
    pass
```

## 指摘出力フォーマット

```markdown
### {重大度}: {チェック項目}

- ファイル: `{path}:{line}`
- 検出: `{検出内容}`
- 推奨: `{推奨修正}`
```

## 自動修正の可否

| チェック項目 | 自動修正可否 |
|------------|-----------|
| SKILL.md 200 行制約 | 不可（構造判断必要） |
| パスポータビリティ | 一部可能（明確な NG パスのみ） |
| プレースホルダ残存 | 不可（置換値の判断必要） |
| frontmatter / JSON valid | 不可 |
| `§` 記号 | 可（代替表現に置換） |
| 必須セクション存在 | 不可 |
| description 文字数 | 不可 |
| `agents/` 削除痕跡 | 可（復元） |
| エンコーディング保持 | 不可（バックアップ必要） |

`--auto-fix` フラグありでも、自動修正可否欄が「不可」の項目はユーザに修正を委ねる。
