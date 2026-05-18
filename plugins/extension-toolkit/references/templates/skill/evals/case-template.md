<!--
B-2 (improvement-backlog) 実行ベース evals 用フロントマター。
自動実行対象とする場合のみ、以下を case ファイル冒頭の --- ... --- に配置する。

---
runnable: true                    # 必須。false / 未指定なら自動実行対象外
command: |                        # 必須。実行するシェルコマンド（pwsh -Command で起動）
  pwsh -NoProfile -File scripts/foo.ps1 -DryRun
expect_exit_code: 0               # 任意（既定: 0）
expect_output_regex:              # 任意（複数可）。全マッチで合格
  - "^\\[OK\\]"
  - "ケース 1: 成功"
expect_output_not_regex:          # 任意（複数可）。1 つでもマッチで失敗
  - "(?i)error"
timeout_sec: 120                  # 任意（既定: 120）
cwd: plugins/{plugin-name}        # 任意（既定: --scope-root 指定パス）
requires_destructive: false       # 任意（true なら run_evals.py --allow-destructive 必須）
env:                              # 任意。実行時に追加する環境変数
  DRY_RUN: "1"
---

自動実行を必要としないケース（仕様書としてのみ機能）はフロントマター不要。
詳細は references/eval-guide.md 節 10「自動実行サポート」を参照。
-->

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
- {具体的な動作 1}
- {具体的な動作 2}

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
