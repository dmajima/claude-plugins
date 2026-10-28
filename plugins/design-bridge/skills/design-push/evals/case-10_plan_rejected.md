# Case 10: ユーザーが push 計画全体を拒否（何も push せず記録も解除しない）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「Claude Design に反映して」 |
| 引数 | なし |
| フラグ | なし（対話モード） |
| 既存状態 | `.claude/design-bridge.json` あり（design-system 型）。認可済み・venv 構築済み。`pending.tsv` に 2 行（`mocks/S001_login.html` と `specs/screens/S001_login.md`）。計画提示に対してユーザーが「やめる」「今は反映しない」と回答する |

## 期待動作

### Phase 1-4: 対象決定からバンドル作成まで
- 引数が無いため対象は `pending.tsv` の全件（2 件）。対象集合として記録する
- `capture.py` が exit 0 で完了し、`specs/assets/S001_login.png` が再生成される
- `specs/screens/S001_login.md` の画面イメージセクションを更新する
- バンドルを作り直し、`screens/S001_login.html` を配置する

### Phase 5: 計画提示で拒否される
- `get_project` で design-system 型を確認する
- `list_files` でリモート構成を取得し、追加 / 更新 / 削除を判定する
- push 計画をユーザーに提示する
- **ユーザーが計画全体を拒否する**
- `finalize_plan` を呼ばない
- `write_files` / `delete_files` を呼ばない
- 計画を縮小して一部だけ送る、といった独自判断の代替実行を行わない。拒否は「今は反映しない」という指示として扱う

### Phase 6-7: マニフェスト更新と記録解除を行わない
- `last-push.json` を更新しない
- **`clear_pending.sh` を呼び出さない。** `pending.tsv` の 2 行をそのまま残す
- `block-count` と `dismissed` も変更しない
- バンドルを削除しない（`--drop-bundle` を使う場面ではない）

### Phase 8: 報告
- 計画が拒否されたため何も push していないことを明示する
- ローカル側（PNG の再生成と設計書の画面イメージ更新）は実行済みであることを伝える
- 未反映のまま残っていること、次の応答終了時に Stop フックが再度ブロックしうることを伝える
- 反映が不要な変更であれば、その旨を確認したうえで `clear_pending.sh` で記録を解除する選択肢があることを案内してよい（Claude の判断だけで解除しない）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの確認 | push 計画の提示（結果は拒否） |
| 外部呼び出し | `get_project` と `list_files` のみ。`finalize_plan` / `write_files` / `delete_files` は 0 回 |
| 生成ファイル | `specs/assets/S001_login.png`、`bundle/screens/S001_login.html`（ローカル側のみ） |
| 更新しないファイル | `last-push.json` |
| 残存ファイル | `pending.tsv`（2 行のまま）、`block-count`・`dismissed`（あれば保持）、`bundle/` |
| `clear_pending.sh` の呼び出し | 0 回 |
| 標準出力（要約） | 何も push していないこと、ローカル側は更新済みであること、未反映のまま残っている旨 |
| 終了状態 | 中断（ユーザー判断による。失敗ではない） |

## 分岐の根拠

このケースが分岐するトリガーは push 計画への応答 = 拒否 である。SKILL.md の「ユーザーが計画全体を拒否した場合は、何も push せず中断する。未反映記録は解除しない」、および解除範囲の表の「全体失敗・認可エラー・計画拒否 → 解除しない」に基づく。

重要なのは `finalize_plan` に到達しないことである。`finalize_plan` は `writes` / `deletes` / `localDir` を確定する操作であり、拒否された計画を確定させてはならない。

case-03 との違いは拒否の範囲である。case-03 は削除候補のみを拒否して `writes` を続行するのに対し、本ケースは計画全体の拒否であるため push そのものを行わない。

## 関連ケース

- [case-01_pending_all.md](case-01_pending_all.md)（同じ入力・同じ対象集合で、計画が承認された場合は push と `--all --drop-bundle` での解除まで進む）
- [case-03_all_mocks.md](case-03_all_mocks.md)（削除候補のみの拒否であれば `writes` のみで計画を確定して続行する）
- [case-05_push_failure.md](case-05_push_failure.md)（同じく記録を温存する中断だが、原因がユーザー判断ではなく送信失敗である）
