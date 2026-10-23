# Case 05: write_files が完全失敗（記録を一切解除しない）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「Claude Design に反映して」 |
| 引数 | なし |
| フラグ | なし（対話モード） |
| 既存状態 | `.claude/design-bridge.json` あり（design-system 型）。認可済み・venv 構築済み。`pending.tsv` に 4 行（`S001_login` と `S002_home` のモックと設計書）。`get_project` / `list_files` / `finalize_plan` は成功するが、`write_files` が全件エラーを返す（ネットワーク断・一時的な拒否などを想定）。`block-count` に Stop フックのブロック回数が記録されている |

## 期待動作

### Phase 1-4: 対象決定からバンドル作成まで
- case-01 と同様に進行する。対象集合（モック 2 件と設計書 2 件）の確定、スクリーンショットの再生成、設計書の画面イメージ更新、バンドル作成までは正常に完了する
- この時点でローカル側の成果物（PNG・設計書の画面イメージ）は更新済みだが、Claude Design への反映はまだ行われていない

### Phase 5: DesignSync による push（全件失敗）
- `get_project` → `list_files` → 計画提示 → 承認 → `finalize_plan` までは成功し `planId` を得る
- `write_files` がエラーを返し、**1 件も送信できなかった**ことを確認する
- エラー内容（どのファイルが送れなかったか、原因は何か）を把握する
- `finalize_plan` を経ずに `write_files` を再試行しない

### Phase 6: push マニフェストを更新しない
- push に成功したファイルが 1 件も無いため、`last-push.json` を更新しない
- 前回の記録が残っている場合は、そのまま温存する（成功していない push で基準点を進めない）

### Phase 7: 未反映記録を一切解除しない（本ケースの中心）
- 解除範囲の表の「全体失敗・認可エラー・計画拒否」に該当する
- **`clear_pending.sh` を呼び出さない**（`--all` も `--path` も使わない）
- `pending.tsv` の 4 行をすべて保持する
- `block-count` と `dismissed` も変更しない
- `bundle/` は削除しない（`--drop-bundle` を使う場面ではない。再試行時に再利用できる）
- 不変条件: **反映が確認できていないパスは、いかなる場合も `pending.tsv` に残る**

### Phase 8: 報告
- push が失敗したことと、失敗したファイル一覧・エラー原因を明示する
- 未反映のまま残っていること、Stop フックが再度ブロックしうることを伝える
- 原因に応じた再実行（時間をおいての再試行、256 ファイル上限に掛かる場合は同一 `planId` での分割送信）を案内する
- 「反映しました」という成功報告は行わない
- ローカル側（PNG と設計書の画面イメージ）は更新済みである旨も併せて伝える

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの確認 | push 計画の提示と承認（失敗は承認後に起きる） |
| 生成ファイル | `specs/assets/` 配下の PNG、`bundle/` 配下の HTML（ローカル側は更新済み） |
| 更新しないファイル | `.claude/.local/plugins/design-bridge/last-push.json` |
| 残存ファイル | `pending.tsv`（4 行すべて保持）、`block-count`、`dismissed`（あれば保持）、`bundle/` |
| `clear_pending.sh` の呼び出し | 0 回 |
| 標準出力（要約） | push 失敗の明示、失敗ファイル一覧、未反映のまま残っている旨、再実行手順 |
| 終了状態 | 失敗（成功とは報告しない） |
| 後続の挙動 | 次の応答終了時に Stop フックが再度ブロックしうる（`blockLimit` まで。上限に達すると `dismissed` に記録され、`pending.tsv` の内容が変わるまで再通知されない） |

## 分岐の根拠

このケースが分岐するトリガーは `write_files` の結果 = 全件失敗 である。SKILL.md の重要な制約「push が失敗した状態で未反映記録を解除しない」、および解除範囲の表の「全体失敗・認可エラー・計画拒否 → 解除しない」に基づく。

これは design-push における **最重要の安全性要件** である。失敗時に記録を解除すると、未反映の変更が Stop フックに検出されなくなり、「反映済みのつもりで未反映」という design-bridge が防ごうとしている状態そのものを作り出してしまう。procedures.md の「迷った場合は解除しない側に倒す」はこの判断を言語化したものである。

## 関連ケース

- [case-01_pending_all.md](case-01_pending_all.md)（全件成功した場合にのみ `--all --drop-bundle` での解除が行われる点が対照的）
- [case-06_partial_push_failure.md](case-06_partial_push_failure.md)（同じ `write_files` の失敗でも、一部が成功している場合は成功分だけを `--path` で解除する）
- [case-07_auth_error.md](case-07_auth_error.md)（同じく記録を温存する中断だが、`get_project` の時点で止まるため計画提示にも到達しない）
- [case-10_plan_rejected.md](case-10_plan_rejected.md)（同じく記録を温存するが、失敗ではなくユーザーの判断で push を行わない）
