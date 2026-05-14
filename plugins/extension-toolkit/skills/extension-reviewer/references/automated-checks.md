# 機械的チェック項目

`extension-reviewer` が並列で実施する機械的チェックの一覧と実行方法。

## 実行方式（MANDATORY）

機械チェックは **必ず PowerShell 経由 + venv 内 Python + JSON ファイル出力** で実施すること
（`~/.claude/rules/tools/shell-preference.md` に従い `Bash` ツールではなく `PowerShell` ツールを使う）。

### エンコーディング前提

`~/.claude/settings.json` の `env` で `PYTHONIOENCODING=utf-8` / `PYTHONUTF8=1` がグローバル設定されており、
PowerShell ツール経由で起動される全 Python プロセスは UTF-8 で動作する
（`~/.claude/rules/tools/python-encoding-mandatory.md` 参照）。

各 `.ps1` の先頭で `[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)` を明示するため、
日本語混在出力も文字化けしない。Python 側でも先頭で `sys.stdout.reconfigure(encoding='utf-8')` を実施する
（必須3点セットの2項目）。

### 正しい起動方法

すべてのチェックは `references/scripts/checks/run_checks.py` に統合済み。
PowerShell ツール経由で venv 内 Python を直接呼ぶ。
venv 関連スクリプトはプラグイン直下の `.ps1` を利用する（ADR-024）。

```powershell
$SessionDir = ".claude/.local/work/{yyyyMMdd_nn_summary}"

# 1. venv 構築（初回のみ・プラグイン共通）
pwsh -NoProfile -File "$env:CLAUDE_PLUGIN_ROOT/references/scripts/setup/setup_venv.ps1" `
  -WorkDir "$SessionDir/workspace" `
  -RequirementsPath "$env:CLAUDE_PLUGIN_ROOT/references/scripts/setup/requirements.txt"

# 2. レビュー対象ごとに run_checks.py を実行（出力は JSON ファイル）
& "$SessionDir/workspace/.venv/Scripts/python" `
  "$env:CLAUDE_SKILL_DIR/references/scripts/checks/run_checks.py" `
  --target "<レビュー対象パス>" `
  --scope-root "<スコープルート (パストラバーサル防止)>" `
  --output "$SessionDir/workspace/checks_<対象名>.json"

# 3. 結果は JSON ファイルから Read ツールで読み取って統合する
#    (標準出力には進捗ログのみ。日本語ログも UTF-8 で出力されるため mojibake は発生しない)

# 4. 作業完了後の venv 削除（プラグイン共通）
pwsh -NoProfile -File "$env:CLAUDE_PLUGIN_ROOT/references/scripts/setup/teardown_venv.ps1" `
  -WorkDir "$SessionDir/workspace"
```

詳細な引数仕様は `references/scripts/checks/run_checks.py --help` を参照すること。

### `.sh` の取り扱い（完全廃止）

`~/.claude/rules/tools/shell-preference.md` に従い、プラグイン配下の `.sh` は **完全に廃止** している。
`references/scripts/` 配下のすべてのスクリプトは `.ps1` で実装する。
`run_checks.py` の項目 #12 (Bash 利用禁止) で、`.sh` 残存・`bash` 起動例残存を自動検出する。

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
| 10 | クロスマーケットプレイス依存時 README D-1/D-2/D-3 揃い（ADR-028 / R-2-7） | `plugin.json` + 同階層 `README.md` | High | `check_cross_marketplace_readme` |
| 11 | プラグインに MIT LICENSE 配備（ADR-029） | プラグイン直下 `LICENSE` + `plugin.json.license` + `README.md` | Critical / High | `check_mit_license` |
| 12 | Bash/sh 利用禁止（PowerShell 移行担保、shell-preference.md）| `hooks.json` / `*.sh` / `*.md` | High / Medium | `check_no_bash_invocation` |
| 13 | hook の `shell` フィールド明示（PowerShell 統一補強、shell-preference.md）| `hooks/hooks.json` | High | `check_hook_shell_field` |

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

### 10. クロスマーケットプレイス依存時 README D-1/D-2/D-3 揃い（ADR-028 / R-2-7）

`run_checks.py` の `check_cross_marketplace_readme` 関数が以下を実施する:

1. `plugin.json` の `dependencies` 配列を走査
2. 各エントリが `marketplace` フィールドを持ち、その値が **自プラグイン所属マーケ名と異なる** 場合に「クロスマーケットプレイス依存」と判定
   - 自プラグイン所属マーケ名は target / 親ディレクトリ階層から `.claude-plugin/marketplace.json` を発見し `name` を取得
3. 該当プラグインに対し、同階層 `README.md` 内に以下の 3 ブロックすべてが含まれることを確認:
   - **D-1**: `/plugin marketplace add <URL>` の記載（正規表現）
   - **D-2**: `extraKnownMarketplaces` キーと `autoUpdate` キーの両方が含まれる JSON 例
   - **D-3**: `/plugin install <plugin>@<marketplace>` の記載（正規表現）
4. 不揃いがあれば **High 指摘**（detail に欠落ブロック名と該当依存マーケ名を記録）
5. 同一マーケットプレイス依存のみ・依存なし・`marketplace` フィールド省略の依存しか持たないプラグインはスキップ

詳細仕様は [`../../../references/architecture-decisions.md`](../../../references/architecture-decisions.md) ADR-028 / [`../../../references/readme-policy.md`](../../../references/readme-policy.md) 節 5.1 D を参照。

### 11. プラグイン MIT LICENSE 配備チェック（ADR-029）

レビュー対象がプラグイン（`plugins/{name}/.claude-plugin/plugin.json` を持つディレクトリ）の場合、以下を確認する:

| 検査項目 | 重大度 | 検出方法 |
|---------|-------|---------|
| `plugins/{name}/LICENSE` の存在 | Critical | ファイル存在確認 |
| `LICENSE` 本文が MIT 標準文（[`../../../references/license-policy.md`](../../../references/license-policy.md) 節 2.2）と一致（copyright 行除く） | Critical | 行単位比較（copyright 行は除外）|
| `Copyright (c) <year> <holder>` の `<year>` `<holder>` が空でなく、プレースホルダ `{year}` `{copyright_holder}` 未残存 | Critical | 正規表現 `^Copyright \(c\) (\S.+) (\S.+)$` |
| `plugin.json.license == "MIT"` | Critical | JSON フィールド確認 |
| `README.md` に「ライセンス」セクションが存在し、`LICENSE` への相対リンクが含まれる | High | 見出しパターン + リンク検出 |

不備時は `mit-license-toolkit` への接続を案内する（自動修正不可、利用者の意思確認 + 著作権情報入力が必要なため）。

`run_checks.py` の `check_mit_license` 関数で機械チェック実装済み。`$CLAUDE_PLUGIN_ROOT/skills/mit-license-toolkit/references/template/LICENSE` を SSOT として参照し、本文の行単位比較（copyright 行除く）+ Copyright 行の正規表現検証 + `plugin.json.license == "MIT"` を一括検査する。

詳細仕様は [`../../../references/license-policy.md`](../../../references/license-policy.md) を参照。

### 12. Bash/sh 利用禁止チェック（PowerShell 移行担保）

`~/.claude/rules/tools/shell-preference.md` で `Bash` ツール利用が禁止されたため、
プラグイン側でも以下を機械チェックで担保する。

| 検査項目 | 重大度 | 検出方法 |
|---------|-------|---------|
| `hooks/hooks.json` の `command` フィールド先頭が `bash` で始まる | High | JSON パース後に再帰的に `command` キーを走査し、正規表現 `^\s*bash\s+` をマッチ |
| `.sh` ファイルが残存している | High | `target.rglob("*.sh")` を走査し、検出されれば High 指摘（`.sh` は完全廃止のため） |
| `.md` 内に `bash ...sh` 起動例がコードフェンス・バッククォート外で残存 | Medium | `iter_inspectable_lines` 経由で正規表現 `(?<![A-Za-z0-9_/.\-])bash\s+["']?[^\s"']*\.sh\b` をマッチ |

除外条件:

- `templates/` / `template/` / `evals/` / `checklists/` 配下（テンプレート・チェック項目記述自体は許容）
- `automated-checks.md` / `shell-preference.md` / `run_checks.py`（自己参照）

運用ポリシー:

- `.sh` は **すべて廃止**。プラグイン配下に `.sh` を含めてはならない
- すべてのシェルスクリプトは `.ps1` で記述する
- `hooks.json` は **常に** `pwsh -NoProfile -File ...ps1` 形式で記述する

### 13. hook の `shell` フィールド明示チェック（PowerShell 統一補強）

`command` を `pwsh -NoProfile -File ...` で書いていても、Claude Code の起動側シェルが
Git Bash の場合に引数解釈・PATH 解決でエッジケースが発生しうる。これを抑制するため、
各 hook エントリで `"shell": "powershell"` を **明示** することを必須化する。

| 検査項目 | 重大度 | 検出方法 |
|---------|-------|---------|
| `hooks/hooks.json` 内の各 hook エントリ（`type: "command"` を持つ）に `"shell"` フィールドが存在する | High | JSON パース後に `hooks` → イベント名 → エントリ → `hooks` 配列の各要素を走査し、`type: "command"` であって `"shell"` キーが無いものを検出 |
| `"shell"` フィールドの値が `"powershell"` または `"bash"` である | High | 値が上記いずれかでない場合は不正値として High 指摘 |
| 本マーケットプレイスのプラグインで `"shell": "bash"` が設定されている | Medium | PowerShell 統一方針との不整合として Medium 指摘（許可ではあるが警告） |

除外条件:

- `templates/` / `template/` / `evals/` 配下（テンプレート・テスト fixture）
- `type: "command"` 以外のエントリ（将来拡張に備える）

実装関数: `check_hook_shell_field`

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
| クロスマーケットプレイス依存時 D-1/D-2/D-3 | 不可（README 全体構造の判断要） |
| MIT LICENSE 配備（ADR-029） | 不可（著作権情報の確認が必要、`mit-license-toolkit` で対応） |

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
