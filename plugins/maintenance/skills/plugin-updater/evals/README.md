# plugin-updater evals

`plugin-updater` スキルの動作分岐を網羅する eval ケース集。`/update-all` コマンド経由で
本スキルが起動された際の Phase A-0〜G の実行を検証する。

## ケース一覧

| # | ファイル | 検証する分岐 |
|---|---------|-------------|
| 01 | `case-01_dry_run.md` | `--dry-run` モード（Phase F まで実行、変更系 CLI 呼び出しなし） |
| 02 | `case-02_scope_user.md` | `--scope user` 正常系 |
| 03 | `case-03_scope_project.md` | `--scope project` 正常系 |
| 04 | `case-04_scope_local.md` | `--scope local` 正常系 |
| 05 | `case-05_scope_all.md` | `--scope all`（既定）正常系 |
| 06 | `case-06_invalid_scope.md` | 不正な `--scope` 値（A-0-1 バリデーション失敗） |
| 07 | `case-07_cli_missing.md` | `claude plugin` CLI 不在（A-0-2 失敗） |
| 08 | `case-08_circuit_breaker.md` | Phase B サーキットブレーカー発動（MP 単位累計 3 件 Failed） |
| 09 | `case-09_phase_g_retry.md` | Phase G 失敗対応 AskUserQuestion + リトライ |
| 10 | `case-10_a_sec_secret_isolation.md` | A-Sec シークレット非接触（`enabledPlugins` 以外のキー混入禁止）|

## 設計方針

- 各ケースは独立して理解可能（前提・入力・期待動作・期待出力を明示）
- 分岐の根拠（どの引数 / 環境状態がそのケースに該当するか）を明記
- 関連ケース（類似分岐や対照ケース）への相互参照を含める
- ケースファイル名は `case-NN_<英語スラッグ>.md` 形式（kebab-case）

## 関連 ADR

- ADR-PU-001 / ADR-PU-010: プラグイン構成と `maintenance` への統合
- ADR-PU-002: 公式 CLI 経由限定
- ADR-PU-003: Phase 順序の厳守
- ADR-PU-005: exit code 一次判定 + Unknown 区分
- ADR-PU-006: サーキットブレーカー
- ADR-PU-007 / ADR-PU-009: 失敗対応の対話モデル
- ADR-PU-008: コマンド/スキル責務分離
