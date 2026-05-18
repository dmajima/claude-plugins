# Case 19: PSScriptAnalyzer キャッシュ不在時のフェイルオープン skip（B-1 統合）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`some-plugin` をレビュー（PowerShell スクリプト含有）" |
| 引数 | `some-plugin`（`.ps1` を含む）|
| フラグ | なし |
| 既存状態 | 以下のいずれか:<br>(a) `pwsh` 未インストール<br>(b) `setup_psmodule.ps1` 不在<br>(c) PSGallery 到達不能 + キャッシュ未作成（初回 DL 失敗）<br>(d) キャッシュのハッシュ整合性失敗（sec-H-1、改ざん疑い） |

## 期待動作

### Phase 1: 機械チェック（PSA 以外は通常通り）

`run_checks.py` の CHECKS リスト 1〜13 番が通常実行される。

### Phase 2: PSA チェック起動 + フェイルオープン

`check_psscriptanalyzer` が起動するが、以下のいずれかの判定で **PSA だけが skip** される（他のチェックは続行）:

| ケース | 判定経路 | skipped reason |
|--------|---------|---------------|
| (a) pwsh 未インストール | `subprocess.run(["pwsh", "-Command", "$null"])` で FileNotFoundError | `pwsh not found` 相当（return せずに何もしない経路）|
| (b) setup_psmodule.ps1 不在 | `Test-Path -LiteralPath $setupScript` で false | `setup_psmodule.ps1 not found` |
| (c) PSGallery 不到達 + キャッシュなし | `setup_psmodule.ps1` exit 3 / status=unavailable | `no cache available and Save-Module failed` |
| (d) ハッシュ不整合 | `setup_psmodule.ps1` exit 4 / status=integrity_failed | `integrity check failed (sec-H-1): cached PSScriptAnalyzer hash mismatch detected. キャッシュを手動削除して再 DL してください` |

### Phase 3: 結果 JSON 出力

PSA 検査自体は **skipped** となり、他のチェック結果のみが `run_checks.py` の出力 JSON に集計される。**全体エラーにはならず**、他チェックの判定結果に応じて APPROVE / CONDITIONAL_APPROVE / REJECT が決定する。

`run_psscriptanalyzer.ps1` が JSON ファイルに以下を書き出す:

```json
{
  "status": "skipped",
  "reason": "setup_psmodule.ps1 exit=3, status='unavailable': no cache available and Save-Module failed",
  "issues": []
}
```

### Phase 4: 引き渡し

```text
総合判定: APPROVE（PSA はスキップ、他のチェックは OK）

機械チェック注意:
- PSScriptAnalyzer (チェック 14): SKIPPED
  reason: setup_psmodule.ps1 exit=3, status='unavailable'
  → PSGallery への到達を確認するか、手動で
    Save-Module -Name PSScriptAnalyzer -RequiredVersion 1.22.0 を実行してください
    (ハッシュ整合性失敗 (sec-H-1) の場合は psmodules キャッシュを手動削除して再 DL)
```

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| `run_psscriptanalyzer.ps1` の標準出力 | `[SKIP] PSScriptAnalyzer cache unavailable (exit=N): <理由>` |
| `run_checks.py` の標準出力 | `[OK] PSScriptAnalyzer 静的解析（B-1）` （exception 経路に入らない限り OK 扱い）|
| PSA 検査の JSON 結果 | `status: "skipped"` |
| 終了状態 | 他チェック次第（PSA skip 単独では失敗しない、フェイルオープン）|

## 分岐の根拠

ADR-033 で「PSScriptAnalyzer モジュール未インストール時はフェイルオープン」を採択している。`automated-checks.md` 節 14 のフェイルオープン挙動 4 段階（pwsh 未インストール / setup_psmodule 不在 / setup exit != 0 / 既存キャッシュ再利用）に従う。sec-H-1（exit 4 / integrity_failed）追加分も同じ skip 経路に統合する。

## 関連ケース

- `case-10_approve_clean.md`（PSA 検出 0 件で APPROVE、PSA 走行成功）
- `case-18_psscriptanalyzer_findings.md`（PSA 検出 1 件以上、CONDITIONAL_APPROVE）
- ADR-033（PowerShell モジュール専用キャッシュ管理）
