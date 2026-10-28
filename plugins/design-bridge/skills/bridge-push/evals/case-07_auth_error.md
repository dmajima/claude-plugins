# Case 07: 認可エラー（/design-login を案内して中断・記録を温存）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「Claude Design に反映して」 |
| 引数 | なし |
| フラグ | なし（対話モード） |
| 既存状態 | `.claude/design-bridge.json` あり（`projectId` 設定済み）。venv 構築済み。しかし `/design-login` による design-system 認可が未実施、または認可が失効しており、`DesignSync` が認可エラーを返す。`pending.tsv` に 2 行（`mocks/S001_login.html` と `specs/screens/S001_login.md`） |

## 期待動作

### Phase 1: 導入確認と対象決定
- `.claude/design-bridge.json` を読み、導入済みであることを確認する
- 対象を `pending.tsv` の 2 件に決定し、対象集合として記録する

### Phase 2-4: スクリーンショット・設計書・バンドル
- `capture.py` が正常終了し、`specs/assets/S001_login.png` が再生成される
- 設計書の画面イメージセクションが更新される
- バンドルが作り直され、`screens/S001_login.html` が配置される
- 認可の有無はここでは判明しない。`DesignSync` を最初に呼ぶのは手順 5 であるため、ローカル側の更新はすべて完了した状態で手順 5 に入る

### Phase 5: DesignSync の最初の呼び出しで認可エラーを検出
- 呼び出し順序どおり `get_project` から開始する
- `get_project` が認可エラーを返す
- 認可が無い状態では `list_files` も `finalize_plan` も `write_files` も成功しないため、**後続の `DesignSync` 呼び出しを行わずに中断する**
- Claude 側で認可を回避する手段（別経路での送信、再試行ループ等）を試みない

### Phase 6-7: マニフェスト更新と記録解除を行わない
- `last-push.json` を更新しない
- **`clear_pending.sh` を呼び出さない。** `pending.tsv` の 2 行をそのまま残す
- `block-count` と `dismissed` も変更しない
- バンドルを削除しない（認可後の再実行でそのまま使える）
- 設計書を「反映済み」として扱わない

### Phase 8: 報告
- design-system への認可が無いため反映できないことを明示する
- ユーザーに `/design-login` の実行を依頼する
- 認可後に `bridge-push` を再実行すれば、未反映の 2 件がそのまま対象になることを伝える
- ローカル側（PNG・設計書の画面イメージ）は更新済みである旨を添える

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの依頼 | `/design-login` の実行 |
| 外部呼び出し | `get_project` のみ（`list_files` / `finalize_plan` / `write_files` / `delete_files` は呼ばない） |
| 更新しないファイル | `last-push.json` |
| 残存ファイル | `pending.tsv`（2 行のまま）、`block-count`・`dismissed`（あれば保持）、`bundle/` |
| `clear_pending.sh` の呼び出し | 0 回 |
| 標準出力（要約） | 認可エラーの明示、`/design-login` の案内、再実行手順 |
| 終了状態 | 中断（未反映のまま） |

## 分岐の根拠

このケースが分岐するトリガーは `DesignSync` の応答 = 認可エラー である。procedures.md の解除範囲の表で「認可エラー → 解除しない。`/design-login` を案内して中断」と定義された分岐にあたる。

前提条件（design-system 認可）の不足は Claude 側では解消できず、ユーザーの操作を必要とする。そのため自動リトライや代替経路の探索ではなく、明示的な案内と中断が正しい振る舞いになる。

認可エラーは `DesignSync` の最初の呼び出しで判明するため、ローカル側の更新（手順 2〜4）はすでに完了している。中断してもローカル成果物を巻き戻さない点が、手順 2 で止まる case-09 との違いである。

## 関連ケース

- [case-08_not_design_system.md](case-08_not_design_system.md)（同じ `get_project` 段階の中断だが、原因が認可ではなくプロジェクト型の誤りであり、案内先が `bridge-init` になる）
- [case-05_push_failure.md](case-05_push_failure.md)（同じく記録を温存する失敗だが、計画確定後の `write_files` 段階で起きる）
- [case-09_screenshot_venv_missing.md](case-09_screenshot_venv_missing.md)（同じく前提不足による中断だが、手順 2 で止まるためバンドル作成にも到達しない）
- [case-01_pending_all.md](case-01_pending_all.md)（認可済みであれば同じ入力で通常の push フローが完走する）
