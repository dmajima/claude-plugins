# 機械的チェック項目

`extension-reviewer` が並列で実施する機械的チェックの一覧と実行方法。

## 実行方式（MANDATORY）

機械チェックは **必ず Bash 経由 + venv 内 Python + JSON ファイル出力** で実施すること。
PowerShell から Python を直接起動することは禁止する。

### 禁止事項（文字化け防止）

以下の組み合わせは Claude Code の stdout 解釈と衝突し、UTF-8 → Latin-1 mojibake
（`â€` パターン等）を発生させるため **使用禁止**:

- `PowerShell` から `python` を直接起動（`pwsh -c "python ..."` など）
- `chcp 65001` / `[Console]::OutputEncoding=[Text.Encoding]::UTF8` の手動切り替え
- Python スクリプトから日本語を **stdout に書き出す**（必ずファイルに書く）
- `$env:PYTHONIOENCODING='utf-8'` の手動付与による回避策

これらは PowerShell サブプロセスのコンソール CP が親ターミナルへ伝播・干渉するため、
Python 側で `sys.stdout.reconfigure(encoding='utf-8')` を入れても根本解決にならない。

### 正しい起動方法

すべてのチェックは `references/scripts/checks/run_checks.py` に統合済み。Bash 経由で起動する。
venv 関連スクリプトはプラグイン直下（ADR-024）。

```bash
SESSION_DIR=".claude/.local/work/{yyyyMMdd_nn_summary}"

# 1. venv 構築（初回のみ・プラグイン共通）
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.sh" \
  "$SESSION_DIR/workspace" \
  "${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/requirements.txt"

# 2. レビュー対象ごとに run_checks.py を実行（出力は JSON ファイル）
"$SESSION_DIR/workspace/.venv/Scripts/python" \
  "${CLAUDE_SKILL_DIR}/references/scripts/checks/run_checks.py" \
  --target "<レビュー対象パス>" \
  --scope-root "<スコープルート（パストラバーサル防止）>" \
  --output "$SESSION_DIR/workspace/checks_<対象名>.json"

# 3. 結果は JSON ファイルから Read ツールで読み取って統合する
#    （標準出力には進捗ログのみ・日本語ログも Bash 経由なので mojibake は発生しない）

# 4. 作業完了後の venv 削除（プラグイン共通）
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/teardown_venv.sh" \
  "$SESSION_DIR/workspace"
```

詳細な引数仕様は `references/scripts/checks/run_checks.py --help` を参照すること。

## チェック項目一覧

| # | 項目 | 対象 | 違反時の重大度 | 実装関数 |
|---|-----|-----|--------------|--------|
| 1 | SKILL.md 200 行制約 | 各 `SKILL.md` | High | `check_skill_md_line_count` |
| 2 | パスポータビリティ | 全テキストファイル | High | `check_path_portability` |
| 3 | プレースホルダ残存 | `*.md` / `*.json` | High | `check_placeholders` |
| 4a | frontmatter valid | `SKILL.md` / `commands/*.md` / `agents/*.md` | High | `check_frontmatter_valid` |
| 4b | JSON valid | `*.json` | Critical | `check_json_valid` |
| 5 | `§` 記号 | 全テキストファイル | Medium | `check_section_symbol` |
| 6 | 必須セクション存在 | `SKILL.md` | High | `check_required_sections` |
| 7 | description 文字数 | `plugin.json` / `commands/*.md` | Medium | `check_description_length` |
| 7.5 | コマンド `argument-hint` 必須（ADR-023） | `commands/*.md` | High | `check_argument_hint` |
| 8 | エンコーディング保持 | 編集ファイル（差分）| Critical | （`run_checks.py` 対象外。`Edit`/`Write` ツール側 + ルール `~/.claude/rules/common/file-encoding.md` で担保） |
| 9 | シークレット混入 | プラグイン全体 | Critical | `check_secrets`（`marketplace-publisher` の `secret-scan.md` と同等） |

`run_checks.py` の出力 JSON 構造:

```json
{
  "target": "plugins/foo",
  "scope_root": ".",
  "issue_count": 3,
  "by_severity": {"Critical": 0, "High": 2, "Medium": 1, "Low": 0},
  "issues": [
    {"severity": "High", "item": "...", "file": "...", "line": 42, "detail": "..."}
  ]
}
```

## 各チェックの詳細

### 1. SKILL.md 200 行制約

`SKILL.md` の行数が 200 行を超えていれば High 指摘。詳細を `references/` に分割すべきタイミング。

### 2. パスポータビリティ

[`../../../references/path-portability.md`](../../../references/path-portability.md) に
列挙された NG パターン（Windows ドライブレター・Unix ユーザディレクトリ・環境変数・
HOME 変数・UNC パス）を Grep で検出する。

`run_checks.py` は以下を **検査対象から除外** する:

- マークダウンのフェンス付きコードブロック (` ``` ... ``` `) 内
- マークダウンのインラインバッククォート (`` `...` ``) 内
- シェル / Python / PowerShell の行頭コメント (`# ...`)
- 自己参照ファイル（`run_checks.py` / `path-portability.md` / `secret-scan.md` 自身）
- `evals/` `templates/` 配下

### 3. プレースホルダ残存

`{kebab-case}` パターンを Grep。テンプレート系ファイル（`templates/` 配下）は除外。
コードブロック・バッククォート内も除外する（`run_checks.py` 実装）。

### 4. frontmatter / JSON valid

YAML / JSON のパースエラーを検出。`templates/` 配下のひな形は frontmatter 完備でない
設計のため除外する。

### 5. `§` 記号検出

[`~/.claude/rules/common/document-rules.md`](https://github.com/dmajima/claude-plugins) の
禁止記号ルールに基づく検出。Medium 指摘 + 代替表現を提案。

### 6. 必須セクション存在チェック

`SKILL.md` に「責務 / 責務外 / トリガー条件 / 前提 / 実行フロー / 重要な制約」が
すべて存在するか確認。**見出しの先頭一致** で判定する（`## 責務外（他スキルが担当）`
は `責務外` にマッチ）。

### 7. description 文字数チェック

| 対象 | 目安 |
|-----|-----|
| プラグイン `description` | 80 文字以内 |
| コマンド `description` | 60 文字以内 |
| スキル `description` | 制限なし（むしろ詳細推奨） |
| エージェント `description` | 制限なし |

超過時は Medium 指摘。

### 7.5. コマンド `argument-hint` 必須化チェック（ADR-023）

`commands/*.md` の frontmatter に `argument-hint` が含まれているか確認する。本文に
`$ARGUMENTS` を参照していて `argument-hint` が無い場合は **High 指摘**。
`argument-hint` の値に改行が含まれる、または 60 文字を超える場合は Medium 指摘。

### 8. エンコーディング保持

`run_checks.py` の対象外。編集前後でバイト列を比較するチェックは `Edit`/`Write`
ツール呼び出しと同期して実施する必要があり、別経路で運用する
（[`~/.claude/rules/common/file-encoding.md`](https://github.com/dmajima/claude-plugins)
を参照）。

### 9. シークレット混入チェック

詳細パターンと検出ロジックは
[`../../marketplace-publisher/references/secret-scan.md`](../../marketplace-publisher/references/secret-scan.md)
を参照。`run_checks.py` の `check_secrets` 関数で同等のロジックを実装している。
検出時は **Critical 指摘**（公開フローを中断）。

## 指摘出力フォーマット

JSON ファイル内の各 issue:

```json
{
  "severity": "High",
  "item": "パスポータビリティ違反: Windows ドライブレター",
  "file": "plugins/foo/scripts/setup_venv.sh",
  "line": 42,
  "detail": "対象行のスニペット（200 文字まで）"
}
```

レビューレポートに転記する際の人間可読フォーマット:

```markdown
### {重大度}: {項目}

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
| argument-hint | 不可（適切な短縮表現の判断要） |
| エンコーディング保持 | 不可（バックアップ必要） |
| シークレット混入 | 不可（必ずユーザ確認） |

`--auto-fix` フラグありでも、自動修正可否欄が「不可」の項目はユーザに修正を委ねる。

## 既知の制約

- `iter_inspectable_lines()` は CommonMark 準拠でフェンス長を厳密に追跡するため、
  外側 4 バッククォート + 内側 3 バッククォートのネストフェンス（PR テンプレート等）も
  正しく解釈する。ただしマークダウン側で `~~~` と ` ``` ` を混在ネストしている等の
  非典型ケースは想定外。
- `run_checks.py` は **動的な振る舞い**（実行時の挙動）はチェックしない。
  動作確認は別途エージェント並列レビューで担当する。
- 失敗系の検出（target 不在 / scope 違反 / 巨大ファイル）は exit code と stderr
  プレフィックスでの通知のみで、JSON 出力は生成されない。`extension-reviewer` 側で
  exit code を確認し、エージェント起動を抑制すること（evals: case-16 / case-17 参照）。
- 失敗系のセキュリティログは **stderr の `[ERROR]` プレフィックス行** がそのまま記録対象となる
  （別途のログファイルは生成しない）。`extension-reviewer` 側で stderr を捕捉し、
  進捗管理ファイル（`progress.md`）の「ブロッカー・懸念事項」節に転記する運用を推奨する。
  attacker による意図的な scope 違反試行を検知したい場合は、本スクリプト自体ではなく
  呼び出し元の hook 等で stderr 監視を実装する。
