# Case 50: ラッパー経由で convert_from_pptx.py のオプションが転送される

## 入力

- 入力 PPTX: 任意の有効な PPTX
- 出力 MD: `<セッション>/output.md`
- 起動: `pwsh -NoProfile -File run_via_job.ps1 <input> <output> -PythonExe <py> --no-mermaid --include-notes`

## 期待動作

1. ラッパーは位置パラメータ `InputPath` / `OutputPath` と名前付き `-PythonExe` を解釈
2. **`ValueFromRemainingArguments=$true` の `$ExtraArgs`** に `--no-mermaid --include-notes` が入る
3. `$pythonArgs = @($InputPath, $OutputPath) + $ExtraArgs` で `convert_from_pptx.py` 用引数を構成
4. Start-Job の ScriptBlock 内で `& $py -u $script @pythonArgs` で splatting 起動
5. Python 側で `argparse` が `--no-mermaid` `--include-notes` を解釈し、それぞれ `args.no_mermaid = True` `args.include_notes = True`
6. **`--no-mermaid` が反映**: 図形+コネクタや SmartArt が Mermaid 化されず、テキストフォールバック
7. **`--include-notes` が反映**: PPTX にスピーカーノートがあれば `> [!NOTE]` ブロックとして出力
8. 終了コード: 0

## 期待出力

- 標準出力: `Wrote: <出力MD>` / `Images dir: <basename>_images`
- 出力 MD:
  - ```` ```mermaid ```` ブロックは存在しない（`--no-mermaid` 効果）
  - スピーカーノートあり PPTX なら `> [!NOTE]` ブロックを含む（`--include-notes` 効果）

## 分岐の根拠

`run_via_job.ps1` の ExtraArgs 転送:

```powershell
[Parameter(ValueFromRemainingArguments=$true)] [string[]]$ExtraArgs
...
$pythonArgs = @($InputPath, $OutputPath)
if ($ExtraArgs) {
    # 先頭の "--" セパレータは除去（PowerShell から渡される場合）
    if ($ExtraArgs[0] -eq "--") {
        $ExtraArgs = $ExtraArgs[1..($ExtraArgs.Count - 1)]
    }
    $pythonArgs += $ExtraArgs
}
$job = Start-Job -ScriptBlock {
    param($py, $script, $jobArgs)
    ...
    & $py -u $script @jobArgs 2>&1 | ForEach-Object { "$_" }
    ...
} -ArgumentList $PythonExe, $convertScript, (,$pythonArgs)
```

## 確認パターン

| 入力 | 期待 |
|---|---|
| `... --no-mermaid` | MD に `\`\`\`mermaid` ブロックが 0 件 |
| `... --include-notes` | MD に `> [!NOTE]` ブロックが含まれる（PPTX にノートがあれば） |
| `... --include-hidden` | 非表示スライドも MD に出る |
| `... --max-image-size 1048576` | 1 MiB を超える画像はメタ情報のみ |
| `... -- --no-mermaid` | 先頭の `--` は除去され、`--no-mermaid` が Python に渡る |
| `... --images-dir custom_imgs` | 画像出力先が `custom_imgs/` |

## 実機検証ログ

```
=== Final: wrapper with extra options (--no-mermaid --include-notes) ===
Wrote: ...\out_with_opts.md
Images dir: ...\out_with_opts_images
elapsed: 1.53 sec / rc: 0
out size: 14742 bytes
lines containing 'mermaid' (should be 0 due to --no-mermaid): 0 hits
```

## 関連ケース

- [case-48_wrapper_timeout_exit124.md](case-48_wrapper_timeout_exit124.md): ラッパー固有のタイムアウト
- [case-49_wrapper_no_python_exe_exit2.md](case-49_wrapper_no_python_exe_exit2.md): ラッパー固有の引数エラー
- [case-14_no_mermaid_flag.md](case-14_no_mermaid_flag.md): `--no-mermaid` 単独の動作
- [case-07_speaker_notes.md](case-07_speaker_notes.md): `--include-notes` 単独の動作
