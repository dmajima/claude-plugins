# PowerShell / .NET API 落とし穴 SSOT

`extension-toolkit` 配下のスキル・プラグインで PowerShell スクリプトを書く際に
繰り返し発生し得る .NET / PowerShell の API 落とし穴を蓄積する SSOT。

C-1 由来（改善バックログ、経緯は git 履歴を参照）。各落とし穴は発見契機（コミット SHA・セッション日付）と
回避コードを併記する。新しい落とし穴を発見したら本ファイルに追記すること。

---

## 1. 文字列 API

### 1.1 `String.TrimStart(string)` は char[] 引数として解釈される

| 項目 | 内容 |
|------|------|
| 症状 | `"/foo/bar".TrimStart("/foo/")` のような呼び出しで、文字列接頭辞ではなく **個別文字の集合** (`'/'`, `'f'`, `'o'`, `'b'`, `'a'`, `'r'`) として扱われる |
| 結果 | 期待: `"bar"` / 実際: 文字集合に含まれる先頭文字を全て除去するため、想定外の結果になる |
| 発見契機 | コミット `bbefbd0`（2026-05-18、maintenance プラグイン sync-settings/sync.ps1）|
| 根本原因 | .NET の `String.TrimStart` のオーバーロードは `(params char[])` のみで、`(string)` シグネチャを持たない。PowerShell の柔軟な型変換で文字列が char[] に暗黙変換される |
| **誤** | `$rel = $path.TrimStart('./').TrimStart('/')` ← `.`, `/` の 2 文字集合として扱う（運良く動くが意図と異なる）|
| **正** | `$rel = if ($path.StartsWith('./')) { $path.Substring(2) } else { $path } ; $rel = $rel.TrimStart('/')` |
| 検出方法 | PSScriptAnalyzer（B-1 で導入）は本ケースを直接ルール化していないが、`PSPossibleIncorrectUsageOfRedirectionOperator` 等の関連ルールと併せて目視確認 |

```powershell
# 誤: 接頭辞除去のつもりが char[] 解釈
"./foo".TrimStart("./")  # → "foo" (運良く期待通り、ただし意図と異なる)
"./.foo".TrimStart("./") # → "foo" (先頭の "./." が char[] '.','/' として全部消える)

# 正: 接頭辞除去は StartsWith + Substring を使う
$s = "./.foo"
if ($s.StartsWith("./")) { $s = $s.Substring(2) }
# → ".foo" (期待通り)
```

---

## 2. ファイル・パス系 API

### 2.1 `Get-ChildItem` の `LinkType` 値は 4 種類（null 含む）

| 項目 | 内容 |
|------|------|
| 症状 | `$item.LinkType -eq 'SymbolicLink'` で判定したが、ジャンクション（Junction）が漏れる |
| 値の種類 | `$null` / `'SymbolicLink'` / `'Junction'` / `'HardLink'` の 4 種 |
| **誤** | `if ($item.LinkType -eq 'SymbolicLink') { ... }` |
| **正** | `if ($item.LinkType -in @('SymbolicLink', 'Junction', 'HardLink')) { ... }` または `if ($item.LinkType) { ... }`（null でなければ全リパースポイント）|

### 2.2 `Resolve-Path` は存在しないパスでエラー

| 項目 | 内容 |
|------|------|
| 症状 | 存在しないパスを `Resolve-Path` に渡すと例外発生 |
| 用途別 | 存在前提: `Resolve-Path` / 存在しなくてもよい: `[System.IO.Path]::GetFullPath((Join-Path (Get-Location) $path))` |
| **誤** | `$abs = (Resolve-Path $userInput).Path` ← 未作成パスでエラー |
| **正** | `$abs = if (Test-Path $userInput) { (Resolve-Path $userInput).Path } else { [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $userInput)) }` |

### 2.3 `Get-FileHash` はディレクトリでエラー

| 項目 | 内容 |
|------|------|
| 症状 | ディレクトリパスを渡すと「指定されたパスが見つかりません」相当のエラー |
| **誤** | `Get-FileHash $path` ← $path がディレクトリの場合エラー |
| **正** | `if ((Get-Item $path).PSIsContainer) { 'directory' } else { (Get-FileHash $path).Hash }` |

---

## 3. 比較・nullability

### 3.1 `$null` との比較は **左辺に $null** を置く

| 項目 | 内容 |
|------|------|
| 症状 | `$value -eq $null` は配列の場合に **要素ごと比較** され、想定外の結果 |
| **誤** | `if ($value -eq $null) { ... }` ← $value が配列だと要素別比較 |
| **正** | `if ($null -eq $value) { ... }` ← 左辺を $null にすると配列との比較でも単一 bool |
| 検出 | PSScriptAnalyzer の `PSPossibleIncorrectComparisonWithNull` ルール（B-1 で有効化済み）|

### 3.2 文字列の空判定

| 項目 | 内容 |
|------|------|
| **誤** | `if ($s -ne $null -and $s -ne '') { ... }` ← 冗長 |
| **正** | `if (-not [string]::IsNullOrWhiteSpace($s)) { ... }` ← 空白文字も除外 |
|        | `if (-not [string]::IsNullOrEmpty($s)) { ... }` ← 空白文字は許可 |

---

## 4. リダイレクト・出力

### 4.1 `2>&1` の対象が PowerShell 関数とネイティブ exe で異なる

| 項目 | 内容 |
|------|------|
| 症状 | PowerShell 関数の `Write-Error` と native exe の stderr で挙動が異なる |
| **誤** | `$result = some-function 2>&1; if ($LASTEXITCODE -ne 0) { ... }` ← PowerShell 関数では `$LASTEXITCODE` は更新されない |
| **正** | PowerShell 関数なら `try { ... } catch { ... }`、native exe なら `& exe-name args 2>&1` + `$LASTEXITCODE` 確認 |

### 4.2 `Write-Host` は文字化けしない、`Write-Output` は文字化けする可能性

| 項目 | 内容 |
|------|------|
| 症状 | `Write-Output "日本語"` で `?` 化、`Write-Host "日本語"` は問題なし |
| 原因 | `Write-Output` はパイプラインに渡るため、下流のホスト/外部プロセスのエンコーディングに依存。`Write-Host` はホスト直書きで `[Console]::OutputEncoding` を尊重 |
| 回避策 | `~/.claude/rules/tools/console-encoding.md` の必須プリフィクス（`chcp.com 65001` + `[Console]::OutputEncoding = UTF8` + `$OutputEncoding = UTF8`）をコマンド冒頭に必ず付与 |
| 注意 | PSScriptAnalyzer は `PSAvoidUsingWriteHost` で `Write-Host` を非推奨扱いするが、ユーザ向け装飾出力では `Write-Host` の方が確実 |

---

## 5. パラメータ・型変換

### 5.1 `[switch]$Flag` のデフォルト値は `[switch]$Flag = $true` ではなく `[switch]$Flag = [switch]$true`

| 項目 | 内容 |
|------|------|
| 症状 | `param([switch]$Flag = $true)` でも動くが、PowerShell の慣用と異なる |
| 推奨 | switch のデフォルトは `$false` 暗黙が標準。`-Flag:$false` で明示的に偽にできる |
| 既定値 true の場合 | `param([bool]$Flag = $true)` の方が読みやすい |

### 5.2 `[int]$LASTEXITCODE` への暗黙変換に注意

| 項目 | 内容 |
|------|------|
| 症状 | `$LASTEXITCODE` は **直前のネイティブコマンド** の終了コードのみ反映。PowerShell コマンドレットは `$?` |
| **誤** | `Some-Cmdlet; if ($LASTEXITCODE -ne 0) { ... }` ← cmdlet は `$LASTEXITCODE` を更新しない |
| **正** | `Some-Cmdlet; if (-not $?) { ... }` または `try { Some-Cmdlet -ErrorAction Stop } catch { ... }` |

---

## 6. JSON / YAML

### 6.1 `ConvertTo-Json` の `-Depth` 既定値は 2

| 項目 | 内容 |
|------|------|
| 症状 | ネストの深いオブジェクトが `System.Collections.Hashtable` 文字列に化ける |
| **誤** | `$obj | ConvertTo-Json` ← Depth=2 で深いネストが切られる |
| **正** | `$obj | ConvertTo-Json -Depth 10`（妥当な上限を指定） |

### 6.2 `ConvertFrom-Json` は PSObject を返し、ハッシュテーブルではない

| 項目 | 内容 |
|------|------|
| 症状 | `(ConvertFrom-Json $text).ContainsKey('foo')` が動かない |
| **誤** | `$json.ContainsKey('foo')` |
| **正** | `$json.PSObject.Properties.Name -contains 'foo'` または PowerShell 7+ なら `ConvertFrom-Json -AsHashtable` |

---

## 7. プロセス起動・PATH

### 7.1 `&` 演算子は PATH 上の最初に見つかったコマンドを起動

| 項目 | 内容 |
|------|------|
| 症状 | `python` が複数バージョン入っていると意図しない python が起動 |
| **正** | venv 内 python を絶対パスで明示: `& "${env:CLAUDE_PLUGIN_ROOT}/.venv/Scripts/python.exe" script.py` |

### 7.2 `Start-Process -Wait` は終了コードを `$LASTEXITCODE` に反映しない

| 項目 | 内容 |
|------|------|
| **誤** | `Start-Process -FilePath foo.exe -Wait; if ($LASTEXITCODE -ne 0) { ... }` |
| **正** | `$p = Start-Process -FilePath foo.exe -Wait -PassThru; if ($p.ExitCode -ne 0) { ... }` または直接呼び出し `& foo.exe` |

---

## 8. 蓄積方針

新しい落とし穴を発見したら、以下を含めて本ファイルに追記する。

| 項目 | 必須 |
|------|------|
| 症状 | はい（再現条件含む）|
| 発見契機（コミット SHA + セッション日付）| はい |
| 根本原因（.NET/PS の仕様レベル）| はい |
| **誤** と **正** のコード対比 | はい |
| 検出方法（PSScriptAnalyzer ルール名等）| 可能なら |

---

## 9. 関連ドキュメント

- `~/.claude/rules/tools/console-encoding.md` — PowerShell コンソール出力エンコーディングのグローバルルール
- `~/.claude/rules/tools/shell-preference.md` — Git Bash 不具合のため PowerShell ツール優先
- [`automated-checks.md`](../skills/extension-reviewer/references/automated-checks.md) 節 14 — PSScriptAnalyzer 統合（B-1）
- ADR-032 — 動作デモ + ユーザ承認フロー必須化（実機検証で本ファイルの落とし穴を検出する補完手段）
