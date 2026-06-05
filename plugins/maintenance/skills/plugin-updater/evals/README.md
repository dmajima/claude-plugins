# plugin-updater evals

`plugin-updater` スキルの動作分岐を網羅する eval ケース集。`/update-all`（`target=all`）または
`/update`（`target=current-project`）コマンド経由で本スキルが起動された際の Phase A-0〜G の実行を検証する。

## ケース一覧

| # | ファイル | 検証する分岐 |
|---|---------|-------------|
| 01 | `case-01_dry_run.md` | `target=all` + `--dry-run` モード（Phase F まで実行、変更系 CLI 呼び出しなし） |
| 02 | `case-02_target_current_project.md` | `target=current-project` 正常系（Phase B/C スキップ、現在の `<repo>` のみ更新） |
| 03 | `case-03_target_all_multi_project.md` | `target=all` + 複数 projectPath 正常系（各 projectPath でグルーピング実行） |
| 04 | `case-04_target_current_project_no_repo.md` | `target=current-project` + git リポジトリ外（A-Repo エラー中断） |
| 05 | `case-05_target_all.md` | `target=all` 正常系（marketplace + user + 全プロジェクトの project/local） |
| 06 | `case-06_invalid_target.md` | 不正な `target` 値（A-0-1 バリデーション失敗） |
| 07 | `case-07_cli_missing.md` | `claude plugin` CLI 不在（A-0-2 失敗） |
| 08 | `case-08_circuit_breaker.md` | Phase B サーキットブレーカー発動（MP 単位累計 3 件 Failed） |
| 09 | `case-09_phase_g_retry.md` | Phase G 失敗対応 AskUserQuestion + リトライ（5 件以下） |
| 10 | `case-10_a_sec_secret_isolation.md` | A-Sec シークレット非接触（`enabledPlugins` 以外のキー混入禁止）|
| 11 | `case-11_a_sec_fail_closed.md` | A-Sec フェイルクローズ（Unicode escape / forbidden_key / 終端未検出 / 4000 行超過） |
| 12 | `case-12_a3_project_path_mismatch.md` | A-3 projectPath 不一致 → Skipped（target=current-project での現在のプロジェクト外） |
| 13 | `case-13_phase_g_6plus_failed.md` | Phase G の Failed 6 件以上（個別判断 UI 非提示） |
| 14 | `case-14_xr5_unknown_threshold.md` | XR-5 Unknown 閾値警告（Unknown 区分が試行済みの 20% 超）|
| 15 | `case-15_a3_installed_plugins_oversize.md` | installed_plugins.json が 4000 行超 / version 非対応 → A-3 スキップ + フォールバック |
| 16 | `case-16_xr5_output_boundary.md` | XR-5 Unknown 区分の境界値（20% ちょうど / 21% 超）|
| 17 | `case-17_target_all_projectpath_missing.md` | `target=all` で全 projectPath ディレクトリ不在 → 全 Skipped |
| 18 | `case-18_target_all_dry_run.md` | `target=all` + `--dry-run`（projectPath ごとグルーピング表示） |
| 19 | `case-19_installed_plugins_empty.md` | installed_plugins.json の plugins が空 → 全 Skipped（未インストール） |
| 20 | `case-20_target_current_project_dry_run.md` | `target=current-project` + `--dry-run`（Phase B/C 省略の実行予定一覧） |
| 21 | `case-21_target_all_no_repo.md` | `target=all` + git リポジトリ外（INFO 表示 + projectPath ベース更新） |

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
- ADR-PU-015: 全プロジェクト更新と `target` パラメータの導入
