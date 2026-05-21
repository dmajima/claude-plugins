# Case 18: PSScriptAnalyzer 検出時の動作（B-1 統合）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`some-plugin` をレビュー（PowerShell スクリプト含有）" |
| 引数 | `some-plugin`（`.ps1` / `.psm1` / `.psd1` を含むプラグイン）|
| フラグ | なし |
| 既存状態 | `~/.claude/.local/plugins/extension-toolkit/psmodules/PSScriptAnalyzer/1.22.0/` にキャッシュ済み（integrity=verified）。対象プラグインに PSA Warning に該当する PowerShell パターン（例: `Get-ChildItem` のエイリアス `gci` 使用、または `$x -eq $null` 比較）が含まれる |

## 期待動作

### Phase 1: 機械チェック

`run_checks.py` の CHECKS リストにより全 15 チェックが順次走行する。最後に `check_psscriptanalyzer`（チェック 14）が走り、以下を実行する:

1. target 配下に `.ps1` / `.psm1` / `.psd1` が存在することを確認
2. `pwsh` が利用可能であることを確認（未インストールならフェイルオープン skip）
3. `run_psscriptanalyzer.ps1` を `pwsh -NoProfile -NonInteractive -File` で起動
4. ps1 側で `setup_psmodule.ps1 -OutputJson <tmp>` を呼び、キャッシュ済みの PSScriptAnalyzer モジュールパスを JSON 経由で取得（integrity=verified を確認）
5. `Import-Module <path>/PSScriptAnalyzer.psd1 -Force` で絶対パス読込
6. `Invoke-ScriptAnalyzer -Path <target> -Recurse -Settings PSScriptAnalyzerSettings.psd1` を実行
7. 結果を IssueCollector 互換 JSON で受け取り、各指摘を CHECKS の指摘リストにマージ

### Phase 2: 重大度マッピング

PSA の Severity を本プラグインの重大度に変換:

| PSA Severity | 本プラグイン重大度 | 想定指摘例 |
|------------|---------------|---------|
| `Error` | High | `PSPossibleIncorrectComparisonWithNull`（左辺 $null 違反）/ `PSAvoidUsingPlainTextForPassword` |
| `Warning` | Medium | `PSAvoidUsingCmdletAliases` / `PSAvoidTrailingWhitespace` |
| `Information` | Low | `PSUseConsistentIndentation` 等 |

### Phase 3: 結果統合

`run_checks.py` の集計に PSA 指摘が追加され、`by_severity` に反映される。`PSA-<RuleName>` を `item` として、`file` には対象 `.ps1` の絶対パス、`line` には行番号、`detail` には PSA メッセージを格納する。

### Phase 4: 総合判定

PSA 検出のみで判定が変わる例（他のチェックが OK の前提）:

| PSA 検出 | 本プラグインの集計 | 総合判定 |
|---------|--------------|---------|
| `PSPossibleIncorrectComparisonWithNull` 1 件 (Error) | High 1 件 | **CONDITIONAL_APPROVE** |
| `PSAvoidUsingCmdletAliases` 3 件 (Warning) | Medium 3 件 | **APPROVE**（Medium は判定に影響しない） |
| エラーなし、Information 5 件 | Low 5 件 | **APPROVE** |

### Phase 5: 引き渡し

```text
総合判定: CONDITIONAL_APPROVE（PSA で High 1 件検出）

機械チェック詳細:
- PSScriptAnalyzer (チェック 14): PSA-PSPossibleIncorrectComparisonWithNull
  file: scripts/foo.ps1:42
  detail: $null should be on the left side of equality comparisons
  fix: `if ($null -eq $value)` の順序に変更

次のアクション:
- 該当箇所を修正後、extension-reviewer を再実行してください
```

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| `run_checks.py` 出力 JSON | `issues[]` に `PSA-<RuleName>` 形式の項目が含まれる、`by_severity` に High/Medium/Low が反映 |
| 標準出力 | `[OK] PSScriptAnalyzer 静的解析（B-1）` の進捗 + 総合判定 |
| 終了状態 | High 1 以上なら CONDITIONAL_APPROVE 判定 |

## 分岐の根拠

`run_checks.py` の `CHECKS` リストに `check_psscriptanalyzer` が登録されており、target 配下に `.ps1`/`.psm1`/`.psd1` が含まれる場合に必ず実行される（ファイル不在の場合はそもそも何もしない）。PSA 検出件数は `automated-checks.md` 節 14 のマッピング表どおりに重大度集計に反映される。総合判定ルールは `review-perspectives.md` 節「総合判定ルール（SSOT）」に従う。

## 関連ケース

- `case-10_approve_clean.md`（PSA 検出 0 件で APPROVE）
- `case-06_conditional_approve.md`（High 1 件以上で CONDITIONAL_APPROVE の標準パス）
- `case-19_psscriptanalyzer_cache_unavailable.md`（PSA モジュール不在時のフェイルオープン skip）
