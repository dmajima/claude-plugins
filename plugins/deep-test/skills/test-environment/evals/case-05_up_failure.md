<!-- TEST-ENVIRONMENT-EVAL-05-SENTINEL-v1 -->
# case-05 up 失敗（ビルド失敗・起動即死 → logs + 理由返却・対話はユーザー URL 確認・skipped 材料）

`action=up` でビルド失敗・起動即死により up が失敗した場合に、失敗理由と logs を返し、対話時はユーザー起動済み URL の提示を確認、非対話時は縮退を確定する分岐を検証する。SUT 品質（ビルドエラー）の修正はしない。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target=orderapp-web base=<base> action=up run-id=R20260719-100000`（対話。`--non-interactive` なし） |
| 起動形態 | 委譲（オーケストレータ `test` の Phase 5 手順 0。全ゲート通過後） |
| 前提 | provision 済み（`environment.yaml` あり・`config_validated: true`）。`up --wait --wait-timeout 120` がビルド失敗または起動即死で非 0 終了する |

## 分岐の根拠

SKILL.md「責務 5」（up）・「責務外」（SUT イメージ・アプリの品質保証は対象外。up 失敗はそのまま理由として返す）・「実行モード判定」（対話: ユーザー起動 URL 提示を確認）、`${CLAUDE_SKILL_DIR}/references/environment-procedures.md` 8.1 章（up 手順 4: 失敗時は logs を取得して理由と共に返却・status.state: down）・9 章縮退表 6 行目（対話: ユーザー URL の提示を確認・非対話: 縮退確定・run 側は skipped〔実行手段不在〕）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 2 章（実行を偽装しない・skipped + reason）。

## 期待動作

- `docker version` 疎通 → environment.yaml の `lifecycle.up_command`（コマンド規約形）を実行し、失敗を exit code で実測する
- 失敗したサービスの `logs` を取得して失敗理由（ビルドエラー・起動即死の要点）を特定する（logs 保存時はマスキング適用）
- ビルドエラー・アプリ不具合の**修正はしない**（SUT の品質保証は対象外。理由をそのまま返す）
- `status.state: down` + `notes`（失敗理由）で environment.yaml を更新する（起動成功を装わない）
- **対話時**: ユーザーへ「起動済み URL を提示して従来前提で続行するか」を AskUserQuestion で確認する（URL 提示 → browser 系は従来どおり実行可能 / なし → 対象レベルは実行時 skipped 材料）
- 起動失敗による半端な残存（作成済みコンテナ）があれば down で片付けてから返却する

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | environment.yaml の `status` 更新（`state: down`・`last_action: up`・`last_run_id: R20260719-100000`・notes に失敗理由）・失敗サービスの logs（`evidence/R20260719-100000/environment/{service}.log`・マスキング適用） |
| 標準出力（要約） | 環境構築結果サマリ（up 失敗の理由・logs パス・ユーザー URL 確認の結果・URL なし時は skipped 材料になる旨） |
| 終了状態 | 失敗理由 + logs を返して終了（実行を偽装しない）。対話ではユーザー判断（URL 提示 or 縮退）を確認済み |

## 関連ケース

- case-04: up 以前の config 検証失敗（早期検出の対）
- case-15: 同じ up 失敗の非対話モード（確認なしで縮退確定する対）
- case-06: up は成功したが health 未達（skipped と blocked の使い分け）
- case-07: 非対話での up 成功（ワンサイクル完結の対）
