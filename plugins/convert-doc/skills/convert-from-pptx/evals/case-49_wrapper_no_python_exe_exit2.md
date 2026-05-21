# Case 49: ラッパーに PythonExe を渡さずに exit 2

## 入力

- 入力 PPTX: 任意の有効な PPTX
- 出力 MD: `<セッション>/output.md`
- 起動: `pwsh -NoProfile -File run_via_job.ps1 -InputPath ... -OutputPath ...`
  - **`-PythonExe` 引数なし** かつ **環境変数 `CONVERT_FROM_PPTX_PYTHON` も未設定**

## 期待動作

1. ラッパーが `$PythonExe` を解決しようとする
2. パラメータ未指定 → `$env:CONVERT_FROM_PPTX_PYTHON` も空
3. `Test-Path $PythonExe` が `false`（空文字列 → 評価失敗）
4. `Write-Error "PythonExe not found. Specify -PythonExe or set CONVERT_FROM_PPTX_PYTHON env var to venv python.exe path."`
5. **終了コード: 2**

## 期待出力

- 標準エラー: `PythonExe not found. Specify -PythonExe or set CONVERT_FROM_PPTX_PYTHON env var to venv python.exe path.`
- 終了コード: **2**
- 出力 MD: 生成されない

## 分岐の根拠

`run_via_job.ps1` の冒頭ガード:

```powershell
if (-not $PythonExe) {
    $PythonExe = $env:CONVERT_FROM_PPTX_PYTHON
}
if (-not $PythonExe -or -not (Test-Path $PythonExe)) {
    Write-Error "PythonExe not found. Specify -PythonExe or set CONVERT_FROM_PPTX_PYTHON env var to venv python.exe path."
    exit 2
}
```

## 追加バリアント: SEC-M2 PythonExe が `.exe` でない

`.bat` / `.cmd` / その他のスクリプトファイルを `-PythonExe` に指定した場合も exit 2:

```powershell
if (-not ($PythonExe.ToLower().EndsWith('.exe'))) {
    Write-Error "PythonExe must be a .exe file: $PythonExe"
    exit 2
}
```

| 入力 | 終了コード | エラーメッセージ |
|---|---|---|
| `-PythonExe` 未指定 + 環境変数なし | 2 | `PythonExe not found. ...` |
| `-PythonExe "存在しないパス"` | 2 | `PythonExe not found. ...` |
| `-PythonExe "fake.bat"` | 2 | `PythonExe must be a .exe file: ...` |
| `-PythonExe "存在する .exe"` | 0（Python 側で続行） | - |

## 実機検証ログ

```
=== T23-5: 存在しない PythonExe ===
rc: 2
>> Write-Error: PythonExe not found. Specify -PythonExe or set CONVERT_FROM_PPTX_PYTHON env var to venv python.exe path.

=== T23-2: SEC-M2 PythonExe が .bat なら拒否 ===
rc: 2
>> Write-Error: PythonExe must be a .exe file: ...\fake_py.bat
```

## 関連ケース

- [case-48_wrapper_timeout_exit124.md](case-48_wrapper_timeout_exit124.md): ラッパー固有のタイムアウト
- [case-50_wrapper_extra_args_passthrough.md](case-50_wrapper_extra_args_passthrough.md): 引数転送
