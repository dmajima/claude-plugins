# Case 48: ラッパーのタイムアウト発火と exit 124 返却

## 入力

- 入力 PPTX: 任意の有効な PPTX
- 出力 MD: `<セッション>/output.md`
- 起動: `bash run_via_job.sh -InputPath ... -OutputPath ... -PythonExe ... -TimeoutSec 1`
  - `TimeoutSec=1` で**意図的に**変換完了より短いタイムアウトを指定

## 期待動作

1. ラッパーは `Start-Job` で Python を起動する
2. `Wait-Job $job -Timeout 1` が `false` を返す（1 秒で未完了）
3. ラッパーは `Write-Error "convert_from_pptx.py timed out after 1 sec"` を出力
4. `Stop-Job $job | Out-Null` を実行（**非同期**）
5. **IMPL-M1**: `Wait-Job $job -Timeout 10 | Out-Null` で Stop の完了を待つ
6. `Receive-Job $job -ErrorAction SilentlyContinue` で partial 出力を回収（あれば Write-Output）
7. `Remove-Job $job -Force` でジョブを破棄
8. **終了コード: 124**（POSIX の SIGKILL 由来 timeout exit code を踏襲）

## 期待出力

- 標準エラー: `convert_from_pptx.py timed out after 1 sec`
- 標準出力: partial 出力（Python が途中まで吐いた行があれば。なければ空）
- 終了コード: **124**

## 分岐の根拠

`run_via_job.sh` のタイムアウト経路:

```bash
# IMPL-M1: Stop-Job は非同期のため Wait-Job で待つ
    Stop-Job $job | Out-Null
    Wait-Job $job -Timeout 10 | Out-Null
    Remove-Job $job -Force
    exit 124
```
## 実機検証ログ

セッション `20260521_01_convert_from_pptx_hung_repro` で本ケースを実機検証済み:

```
=== T23-4: タイムアウト発火 (TimeoutSec=1) → exit 124 ===
rc: 124 / elapsed: 1.65 sec
>> Wrote: ...
>> Images dir: ...
>> 0
```

（Python が完了直前に kill されたケース。partial 出力に `Wrote:` 行が混じることもある）

## 関連ケース

- [case-09_input_not_found.md](case-09_input_not_found.md): 通常エラー時の rc=1 返却
- [case-49_wrapper_no_python_exe_exit2.md](case-49_wrapper_no_python_exe_exit2.md): ラッパー固有の引数エラー
- [case-50_wrapper_extra_args_passthrough.md](case-50_wrapper_extra_args_passthrough.md): 追加オプション転送
