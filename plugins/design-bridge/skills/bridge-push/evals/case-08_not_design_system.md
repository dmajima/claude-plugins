# Case 08: get_project の型が design-system でない（bridge-init を案内して中断）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「Claude Design に反映して」 |
| 引数 | なし |
| フラグ | なし（対話モード） |
| 既存状態 | `.claude/design-bridge.json` あり。認可済み・venv 構築済み。ただし `projectId` が通常プロジェクト（`type` が `PROJECT_TYPE_DESIGN_SYSTEM` ではない）を指している。`pending.tsv` に 3 行 |

## 期待動作

### Phase 1: 導入確認と対象決定
- `.claude/design-bridge.json` を読む。ファイル自体は存在するため `bridge-init` 案内（未導入分岐）には進まない
- 対象を `pending.tsv` の 3 件に決定し、対象集合として記録する

### Phase 2-4: スクリーンショット・設計書・バンドル
- 設定の不整合は `get_project` を呼ぶまで判明しないため、手順 2〜4 は正常に完了する
- PNG の再生成、設計書の画面イメージ更新、バンドル作成までは行われる

### Phase 5: get_project で型の不一致を検出
- 呼び出し順序どおり `get_project` から開始する
- 応答の `type` が `PROJECT_TYPE_DESIGN_SYSTEM` ではないことを確認する
- **通常プロジェクトには push できず、プロジェクト型は作成後に変更できない。** 設定を直さない限り何度試しても成功しないため、リトライせずに中断する
- `list_files` 以降（`finalize_plan` / `write_files` / `delete_files`）を呼ばない
- 別のプロジェクトを勝手に探して push しない。`projectId` を Claude の判断で書き換えない

### Phase 6-7: マニフェスト更新と記録解除を行わない
- `last-push.json` を更新しない
- **`clear_pending.sh` を呼び出さない。** `pending.tsv` の 3 行をそのまま残す
- `block-count` と `dismissed` も変更しない
- バンドルを削除しない

### Phase 8: 報告
- `.claude/design-bridge.json` の `projectId` が design-system 型のプロジェクトを指していないため push できないことを明示する
- プロジェクト型は作成後に変更できないため、`bridge-init` で design-system プロジェクトを用意し直し、`projectId` を設定し直す必要があることを案内する
- 未反映の 3 件はそのまま残っており、設定修正後の再実行で対象になることを伝える

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの案内 | `bridge-init` での再設定（design-system プロジェクトの用意と `projectId` の設定） |
| 外部呼び出し | `get_project` のみ（`list_files` / `finalize_plan` / `write_files` は呼ばない） |
| 更新しないファイル | `.claude/design-bridge.json`（Claude が勝手に書き換えない）、`last-push.json` |
| 残存ファイル | `pending.tsv`（3 行のまま）、`block-count`・`dismissed`（あれば保持）、`bundle/` |
| `clear_pending.sh` の呼び出し | 0 回 |
| 標準出力（要約） | 型不一致の明示、型が変更不能であること、`bridge-init` の案内 |
| 終了状態 | 中断（未反映のまま） |

## 分岐の根拠

このケースが分岐するトリガーは `get_project` の応答 = `type` が `PROJECT_TYPE_DESIGN_SYSTEM` でない である。procedures.md の「`type` が `PROJECT_TYPE_DESIGN_SYSTEM` であることを確認する。通常プロジェクトには push できず、型は作成後に変更できない。異なる場合は中断し、`bridge-init` での再設定を案内する。未反映記録は解除しない」に対応する。

case-07（認可エラー）と同じ `get_project` 段階の中断でありながら、原因が「ユーザーの認可操作の不足」ではなく「設定ファイルの内容の誤り」である点が異なり、案内先も `/design-login` ではなく `bridge-init` になる。型は後から変更できないため、再試行では解決しない点も認可エラーとの差である。

## 関連ケース

- [case-07_auth_error.md](case-07_auth_error.md)（同じ `get_project` 段階の中断だが、原因が認可であり `/design-login` の実行で解決する）
- [case-05_push_failure.md](case-05_push_failure.md)（同じく記録を温存するが、計画確定後の送信段階の失敗である）
- [case-01_pending_all.md](case-01_pending_all.md)（`projectId` が design-system 型を指していれば同じ入力で通常の push フローが完走する）
