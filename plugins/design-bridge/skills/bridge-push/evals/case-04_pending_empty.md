# Case 04: pending.tsv が空（DesignSync も capture.py も呼ばず正常終了）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「Claude Design に反映して」 |
| 引数 | なし |
| フラグ | なし（対話モード） |
| 既存状態 | `.claude/design-bridge.json` あり（design-system 型）。認可済み。直前の `bridge-push` が全件成功しているため `.claude/.local/plugins/design-bridge/pending.tsv` が存在しない（または空）。`last-push.json` は前回の記録が残っている |

## 期待動作

### Phase 1: 導入確認と対象決定
- `.claude/design-bridge.json` を読み、導入済みであることを確認する
- 引数が無いため、対象は `pending.tsv` の全件となる
- `pending.tsv` が存在しない、または空であることを検出する
- 対象決定の条件「`pending.tsv` が空で引数も無い場合」に合致するため、ここで正常終了へ分岐する

### Phase 2 以降: 実行しない
- **`capture.py` を呼び出さない。** 対象 0 件なら `capture.py` 自体は exit 0 を返す実装だが、Phase 1 で正常終了に分岐しているため起動自体を行わない
- 設計書の画面イメージセクションを書き換えない
- バンドルを作成しない（既存の `bundle/` があっても作り直さない）
- **`DesignSync` を一切呼び出さない**（`get_project` も `list_files` も `finalize_plan` も `write_files` も呼ばない）
- `last-push.json` を更新しない
- `clear_pending.sh` を呼び出さない（解除すべき記録が無い）

### Phase 8: 報告
- 「反映すべき変更はありません」と報告して終了する
- 全件を強制的に反映したい場合は `--all` を使えることを案内してよい
- エラーとして報告しない

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの確認 | なし（確認を要する操作を行わないため） |
| 生成ファイル | なし |
| 更新ファイル | なし |
| 外部呼び出し | `DesignSync` 0 回、`capture.py` 0 回、`clear_pending.sh` 0 回 |
| 状態ファイルの変化 | なし（`last-push.json` も `bundle/` もそのまま） |
| 標準出力（要約） | 「反映すべき変更はありません」と、必要なら `--all` の案内 |
| 終了状態 | 成功（正常終了。エラーでも中断でもない） |

## 分岐の根拠

このケースが分岐するトリガーは 引数 = なし かつ `pending.tsv` = 空（または不在） である。SKILL.md の対象決定で明示された早期正常終了の分岐であり、空のバンドルを push して Claude Design 側を意図せず空にする事故を防ぐ役割を持つ。

`capture.py` も `DesignSync` も呼ばないことが本ケースの要点である。対象 0 件でも `capture.py` を起動してしまうと、venv が未構築な環境では不要な失敗（exit 2）を招き、「反映すべき変更が無いだけ」なのに中断として報告されてしまう。

## 関連ケース

- [case-01_pending_all.md](case-01_pending_all.md)（同じ引数なしでも `pending.tsv` が非空なら通常の push フローへ進む）
- [case-03_all_mocks.md](case-03_all_mocks.md)（`pending.tsv` が空でも `--all` を指定すれば `mocksDir` 配下の全モックを対象に push する）
- [case-09_screenshot_venv_missing.md](case-09_screenshot_venv_missing.md)（venv 未整備の環境でも、本ケースでは `capture.py` を呼ばないため中断に至らない）
