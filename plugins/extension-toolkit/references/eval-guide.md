# evals 作成ガイド（SSOT）

動作分岐があるスキルにおける `evals/` の必須要件と作成方法。

## 1. evals が必須となる条件

以下のいずれかに該当するスキルは `evals/` を作成する。

| 条件 | 例 |
|-----|---|
| 入力フラグで動作が変わる | `--non-interactive` の有無で確認動作分岐 |
| 引数の有無で動作が変わる | 引数指定 / 不足時のフロー違い |
| 内部状態（既存ファイル有無等）で動作が変わる | 既存プラグイン更新 / 新規作成の分岐 |
| 重複検出結果で動作が変わる | 重複あり / 部分重複 / 重複なし |
| 起動するサブエージェントが状況依存 | 役割選定がタスク特性で変動 |

該当しないスキル（純粋に手順を実行するだけ）は evals 不要。

## 2. ディレクトリ構造

```
skills/{skill-name}/evals/
├── README.md                    # evals 全体の概要
├── case-{番号}_{ケース名}.md    # 各ケースの期待動作
└── ...
```

## 3. 各ケースファイルのフォーマット

```markdown
# Case {番号}: {ケース名}

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "{ユーザの発話}" |
| 引数 | {引数} |
| フラグ | {フラグ} |
| 既存状態 | {前提となる環境状態} |

## 期待動作

### Phase 1: {フェーズ名}
- {具体的な動作1}
- {具体的な動作2}

### Phase 2: {フェーズ名}
- {動作}

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | {ファイルパス} |
| 標準出力（要約） | {期待されるメッセージ} |
| 終了状態 | {成功/失敗/部分完了} |

## 分岐の根拠

このケースが分岐するトリガーは {入力のどの要素} = {値} である。

## 関連ケース

- `case-{番号}_{他ケース名}.md`（{違いの説明}）
```

## 4. 必須カバレッジ

| カバレッジ | 内容 |
|----------|------|
| 対話モード | 通常実行（フラグなし） |
| 非対話モード | `--non-interactive` 等の自動進行 |
| 主要分岐の各ブランチ | if/else の各経路を 1 ケース以上 |
| エラー系（既知） | 入力不正・前提不足時の動作 |

## 5. 例: skill-toolkit の evals

```
skills/skill-toolkit/evals/
├── README.md
├── case-01_new_skill_interactive.md      # 新規作成・対話モード
├── case-02_new_skill_non_interactive.md  # 新規作成・非対話モード
├── case-03_existing_skill_update.md      # 既存スキル更新
├── case-04_with_python_setup.md          # Python venv セット付き
└── case-05_dependent_external_skill.md   # example-skills/document-skills 連携
```

## 6. README.md（evals 配下）

```markdown
# Evals: {skill-name}

このディレクトリは `{skill-name}` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| case-01 | {内容} | {分岐根拠} |
| case-02 | {内容} | {分岐根拠} |

## 実行確認方法

各ケースの「入力」セクションのフレーズで Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。
```

## 7. evals の更新タイミング

- スキルの分岐ロジックを変更した時
- 新しいケースが発見された時
- ユーザから挙動について指摘を受けた時

## 8. 禁止事項

- 1 ケース 1 ファイル原則の違反（複数ケースを 1 ファイルに混在）
- 期待動作の曖昧記述（「適切に」「うまく」等）
- 分岐根拠の不記載（なぜこのケースが分岐するか書かない）
- 仕様書としての記述を欠いた「実行スクリプトのみ」の case ファイル化（節 10 で自動実行をオプトイン化しても、仕様記述の本文は省略不可）

## 9. 仕様書としての位置づけ

`evals/` は **仕様書としての期待動作の記述** が第一義。自動テスト化（節 10）はあくまでオプトインの補強であり、機械的に検証可能な範囲（標準出力 / 終了コード / 副作用なし）に限定される。AskUserQuestion 実発火 / UI 出力 / インタラクティブ承認 等は機械検証の射程外のため、人間レビューを引き続き必須とする（A-1 のデモ承認フローと相補的）。

実行可能テストが必要な場合（多言語連携・複雑な前提環境）は `tests/` を別途用意し、`scripts/` 配下に実行スクリプトを置く。

## 10. 自動実行サポート（B-2、オプトイン）

`improvement-backlog.md` の B-2 由来。`evals/case-*.md` 冒頭にフロントマターを付与することで、`run_evals.py` から自動実行・diff 検証の対象にできる。

### 10.1 フロントマター仕様

```yaml
---
runnable: true                    # 必須。false / 未指定なら自動実行対象外
command: |                        # 必須。pwsh -Command で起動するシェルコマンド
  pwsh -NoProfile -File scripts/foo.ps1 -DryRun
expect_exit_code: 0               # 任意（既定: 0）
expect_output_regex:              # 任意（複数可）。全マッチで合格
  - "^\\[OK\\]"
  - "ケース 1: 成功"
expect_output_not_regex:          # 任意（複数可）。1 つでもマッチで失敗
  - "(?i)error"
timeout_sec: 120                  # 任意（既定: 120）
cwd: plugins/{plugin-name}        # 任意（既定: --scope-root のパス）
requires_destructive: false       # 任意（既定: false）。true なら --allow-destructive 必須
env:                              # 任意。実行時に追加する環境変数
  DRY_RUN: "1"
---
```

### 10.2 副作用ゼロの担保

| 原則 | 内容 |
|------|------|
| (a) dry-run のみ自動実行可 | `command` 欄には dry-run / --whatif / --check 系のみ記載すること |
| (b) 破壊的操作はオプトイン | 実削除・実適用が必要なケースは `requires_destructive: true` を付与し、`run_evals.py --allow-destructive` フラグなしでは自動スキップ |
| (c) 環境変数で安全装置 | `env: DRY_RUN: "1"` 等の安全フラグを併用 |
| (d) timeout 厳守 | 既定 120 秒、長時間ケースは `timeout_sec` で個別指定 |

### 10.3 起動方法

```powershell
# venv 経由（推奨）
pwsh -NoProfile -File "${env:CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.ps1" "<workspace>"
& "<workspace>/.venv/Scripts/python.exe" `
  "${env:CLAUDE_PLUGIN_ROOT}/references/scripts/evals/run_evals.py" `
  --target plugins/maintenance/skills/cleanup-workspace/evals `
  --output .claude/.local/work/{session}/evals-result.json `
  --scope-root . `
  --parallel 4
```

### 10.4 出力 JSON 構造

```json
{
  "target": "...",
  "total": 19,
  "runnable": 8,
  "passed": 7,
  "failed": 1,
  "skipped": 11,
  "results": [
    {
      "case_file": "...",
      "status": "passed" | "failed" | "skipped",
      "reason": "...",
      "exit_code": 0,
      "duration_sec": 1.23,
      "stdout_preview": "...",
      "stderr_preview": "..."
    }
  ]
}
```

### 10.5 既存ケースのマイグレーション方針

既存 60 件の case-*.md は **そのままで動作する**（フロントマター未指定なら自動 skip）。
段階的に dry-run 系から runnable: true を付与していく方針。
破壊系（実適用 / 実削除）は requires_destructive: true で明示的にオプトインする。

### 10.6 自動実行と人間レビューの併用

機械検証で網羅できない観点（AskUserQuestion 実発火 UX / 視覚的フォーマット / ファイル副作用の妥当性）は **A-1 のデモ承認フロー** で人間レビューを継続する。`run_evals.py` の合格は A-1 の承認を代替しない（相補的な関係）。
