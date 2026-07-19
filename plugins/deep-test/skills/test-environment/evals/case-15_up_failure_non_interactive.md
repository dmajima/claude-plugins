<!-- TEST-ENV-EVAL-R2-15-SENTINEL-v1 -->
# case-15 up 失敗 × 非対話（確認なしで縮退確定・skipped 材料。case-05 の対）

非対話モードの `action=up` でビルド失敗・起動即死により up が失敗した場合に、ユーザー URL 提示の確認（AskUserQuestion）を行わず**縮退を確定**し、失敗理由 + logs を返す分岐を検証する。対話でユーザー URL 提示を確認する主系は case-05 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target=orderapp-web base=<base> action=up run-id=R20260719-150000 --non-interactive` |
| 起動形態 | 委譲（オーケストレータ `test` の Phase 5 手順 0・非対話） |
| 前提 | provision 済み（`environment.yaml` あり・`config_validated: true`）。`up --wait --wait-timeout 120` がビルド失敗または起動即死で非 0 終了する |

## 分岐の根拠

SKILL.md「責務外」（SUT 品質保証は対象外。up 失敗はそのまま理由として返す）・「実行モード判定」（非対話: 曖昧確認をせず進行）、`${CLAUDE_SKILL_DIR}/references/environment-procedures.md` 8.1 章手順 4（失敗時は logs を取得して理由と共に返却・`status.state: down`）・9 章縮退表 6 行目（up 失敗: 非対話は縮退確定・run 側は **skipped**〔実行手段不在。デーモン不可と同列〕）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 2 章（実行を偽装しない・skipped + reason）。

## 期待動作

- environment.yaml の `lifecycle.up_command` を実行し、失敗を exit code で実測する（起動成功を装わない）
- 失敗したサービスの logs を取得・保存し（`evidence/R20260719-150000/environment/`・マスキング適用）、失敗理由の要点を特定する
- **AskUserQuestion を行わない**: ユーザー起動 URL の提示確認をせず、縮退を確定する（対話の case-05 との差）
- `status.state: down` + `notes`（失敗理由）で environment.yaml を更新し、半端な残存（作成済みコンテナ）があれば down で片付けてから返却する
- ビルドエラー・アプリ不具合の修正はしない（SUT の品質保証は対象外）
- 返却に「ユーザー起動 URL があれば従来前提で続行可能・なければ対象レベルは実行時 **skipped**（実行手段不在）」の材料を明示する（オーケストレータは縮退のままフローを止めずに進める）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | environment.yaml の `status` 更新（`state: down`・notes に失敗理由・`last_run_id: R20260719-150000`）・logs（`evidence/R20260719-150000/environment/{service}.log`・マスキング適用） |
| 標準出力（要約） | 環境構築結果サマリ（up 失敗の理由・logs パス・縮退確定・skipped 材料の旨。確認なし） |
| 終了状態 | 確認なしで縮退確定・失敗理由 + logs を返して終了（実行を偽装しない・フローは止めない） |

## 関連ケース

- case-05: 同じ up 失敗の対話モード（ユーザー URL 提示を AskUserQuestion で確認する対）
- case-16: health 未達 × 非対話（skipped と blocked の使い分け: 手段不在 vs 前提不成立）
- case-07: 非対話 up の成功系（ワンサイクル完結の対）
