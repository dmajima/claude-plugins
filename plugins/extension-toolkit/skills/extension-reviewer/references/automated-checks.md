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
| コマンド `argument-hint` 必須（ADR-023） | `commands/*.md` の frontmatter | YAML キー存在 + 本文 `$ARGUMENTS` 有無の照合 | High |
| `agents/` 削除痕跡 | 既存スキル更新時 | git diff | High |
| エンコーディング保持 | 編集ファイル | バイト列比較 | Critical |
| シークレット混入（`.env` / 鍵 / トークン文字列） | プラグイン全体 | ファイル名 + 内容パターン | Critical |

## 実行方法

> **シェル例の安全な扱い（CWE-78 / CWE-88 対策）**:
> 以下の例で `{target_dir}` はテンプレート変数。実行時には **必ずダブルクォートで囲む**（`"{target_dir}"` または `"$TARGET_DIR"`）こと。スペース・`;` ・ `$(...)` を含むパス、シェルメタ文字を含む値が混入するとコマンド注入につながる。
> 機械チェック呼び出し前に「9. エンコーディング保持」節の `assert_in_scope` 関数で、対象がレビュー対象ディレクトリ配下であることを **必ず検証** すること。

### 1. 行数チェック（SKILL.md 200 行）

```bash
TARGET_DIR="{target_dir}"   # ← レビュー対象パス。事前に assert_in_scope で検証する
find "$TARGET_DIR" -name "SKILL.md" -exec wc -l {} \;
```

200 行超過のファイルを High 指摘として記録。

### 2. パスポータビリティ Grep

```bash
# Windows ドライブレター
grep -rn "[A-Za-z]:[\\/]" "$TARGET_DIR"

# Unix ユーザディレクトリ
grep -rn "/home/\|/Users/\|/root/" "$TARGET_DIR"

# Windows 環境変数
grep -rn "%USERPROFILE%\|%APPDATA%\|%LOCALAPPDATA%" "$TARGET_DIR"

# シェル HOME 変数
grep -rn '\$HOME\|\${HOME}' "$TARGET_DIR"

# UNC パス
grep -rn '\\\\[A-Za-z0-9._-]\+\\' "$TARGET_DIR"
```

検出結果を [`../../../references/path-portability.md`](../../../references/path-portability.md) の分類（NG / 例外候補 / OK）に振り分け。

### 3. プレースホルダ残存

```bash
grep -rn '{[a-z][a-z0-9-]*}' "$TARGET_DIR" --include="*.md" --include="*.json"
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
grep -rn '§' "$TARGET_DIR"
```

検出時は Medium 指摘 + 代替表現の提案。

### 6. 必須セクション存在チェック

`SKILL.md` に以下のセクションが存在するか確認:

```bash
grep -E '^## (責務|責務外|トリガー条件|前提|実行フロー|重要な制約)' "$SKILL_MD"
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

### 7.5 コマンド `argument-hint` 必須化チェック（ADR-023）

`commands/*.md` の frontmatter に `argument-hint` が含まれているか確認する。本文に `$ARGUMENTS` を参照していて `argument-hint` が無い場合は **High 指摘**。

```python
import yaml, re, pathlib

def check_argument_hint(command_md: pathlib.Path) -> list[str]:
    issues: list[str] = []
    text = command_md.read_text(encoding='utf-8')
    parts = text.split('---', 2)
    if len(parts) < 3:
        return [f"[High] frontmatter 不在: {command_md}"]
    fm = yaml.safe_load(parts[1]) or {}
    body = parts[2]
    has_arguments = bool(re.search(r'\$ARGUMENTS', body))
    has_routing = bool(re.search(r'^##\s*ルーティング', body, re.M))
    needs_hint = has_arguments or has_routing
    hint = fm.get('argument-hint')
    if needs_hint and not hint:
        issues.append(f"[High] argument-hint 欠落（ADR-023）: {command_md}")
    if hint:
        if '\n' in str(hint):
            issues.append(f"[Medium] argument-hint に改行: {command_md}")
        if len(str(hint)) > 60:
            issues.append(f"[Medium] argument-hint 60 文字超過: {command_md}")
    return issues
```

### 8. `agents/` 削除痕跡（更新時）

```bash
git diff HEAD -- "$TARGET_DIR/*/agents/"
```

スキル内 `agents/` が削除されていたら High 指摘（プラグイン配布のため保持必須）。

### 9. エンコーディング保持

編集前後でバイト列を比較し、文字コード変換が起きていないか確認。

`file_path` は **必ずレビュー対象ディレクトリ配下であることを呼び出し前に検証**（パストラバーサル対策）。
スコープ外のシステムファイルに対して `file` コマンドを実行しないこと。

```python
import subprocess, pathlib

def assert_in_scope(target_dir: pathlib.Path, file_path: pathlib.Path) -> None:
    target_resolved = target_dir.resolve()
    file_resolved = file_path.resolve()
    if target_resolved not in file_resolved.parents and file_resolved != target_resolved:
        raise ValueError(f"out of scope: {file_path}")

assert_in_scope(target_dir, pathlib.Path(file_path))

# 編集前のエンコーディング
before = subprocess.run(['file', '--mime-encoding', file_path],
                        capture_output=True, shell=False).stdout

# 編集後
after = subprocess.run(['file', '--mime-encoding', file_path],
                       capture_output=True, shell=False).stdout

if before != after:
    # Critical 指摘
    pass
```

### 10. シークレット混入チェック

詳細パターンと検出ロジックは [`../../marketplace-publisher/references/secret-scan.md`](../../marketplace-publisher/references/secret-scan.md) を参照。`extension-reviewer` 起動時にも公開前のラストガードとして同チェックを実施する。検出時は **Critical 指摘**（公開フローを中断、ユーザの明示的な対応を要求）。

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
