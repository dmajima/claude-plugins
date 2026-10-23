# Case 09: capture.py が exit 2（venv 未整備・構築を案内して中断）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「Claude Design に反映して」 |
| 引数 | なし |
| フラグ | なし（対話モード） |
| 既存状態 | `.claude/design-bridge.json` あり（design-system 型）。認可済み。`pending.tsv` に 2 行（`mocks/S001_login.html` と `specs/screens/S001_login.md`）。`.claude/.local/plugins/design-bridge/.venv` は存在するが `playwright` が未導入（`setup_venv.sh` が Chromium 導入段階まで到達していない）。このため `capture.py` が exit 2 を返す |

## 期待動作

### Phase 1: 導入確認と対象決定
- `.claude/design-bridge.json` を読み、対象を `pending.tsv` の 2 件に決定する
- 対象集合として記録する

### Phase 2: スクリーンショットの再生成で exit 2
- `Bash` ツール経由で `capture.py` を `--project-root` 付きで起動する
- `capture.py` が標準エラーへ「`playwright` が未導入です。`setup_venv.sh` を実行して venv を構築してください。」を出力し、**終了コード 2** を返す
- 終了コード表の「2 = 引数エラー / 封じ込め違反 / playwright・Chromium 未導入 / `--only` の空振り」に該当するため **中断する**
- 終了コード 2 を無視して続行しない

### Phase 3 以降: 実行しない
- **設計書の画面イメージセクションを更新しない。** スクリーンショットが無いまま画像参照だけ更新すると、存在しない PNG を指す設計書が残る
- バンドルを作成しない
- **`DesignSync` を一切呼び出さない**（`get_project` も含む）
- `last-push.json` を更新しない
- **`clear_pending.sh` を呼び出さない。** `pending.tsv` の 2 行をそのまま残す。`block-count` と `dismissed` も変更しない

### Phase 8: 報告
- スクリーンショットを生成できなかったため反映を中断したことを明示する
- `capture.py` の標準エラー出力をそのまま提示し、原因を伝える
- venv の構築手順（`design-init` の venv 構築、または `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.sh` の実行）を案内する
- Chromium のみ未導入の場合は `"<venv>/Scripts/python.exe" -m playwright install chromium` で解消できることを添えてよい
- 構築後に `design-push` を再実行すれば未反映の 2 件がそのまま対象になることを伝える

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの案内 | venv 構築（`design-init` の venv 構築手順 / `setup_venv.sh`）の実行 |
| 外部呼び出し | `capture.py` 1 回（exit 2）。`DesignSync` 0 回、`clear_pending.sh` 0 回 |
| 生成ファイル | なし（PNG も `bundle/` も作られない） |
| 更新ファイル | なし（設計書・`last-push.json` とも変更しない） |
| 残存ファイル | `pending.tsv`（2 行のまま）、`block-count`・`dismissed`（あれば保持） |
| 標準出力（要約） | exit 2 の明示、`capture.py` のエラーメッセージ、venv 構築手順、再実行の案内 |
| 終了状態 | 中断（未反映のまま） |

## 分岐の根拠

このケースが分岐するトリガーは `capture.py` の終了コード = 2 である。procedures.md の終了コード表が定める 3 分岐のうち、唯一「中断」に倒す値である。

| 終了コード | 意味 | 対応 |
|---|---|---|
| 0 | 全件成功（対象 0 件を含む） | 続行（case-01 / case-03） |
| 1 | 1 件以上失敗 | 失敗したモックを報告し、残りで push を続けるかユーザーに確認。失敗分は解除しない |
| 2 | 引数エラー / 封じ込め違反 / playwright・Chromium 未導入 / `--only` の空振り | 中断。原因別に案内する（本ケース） |

exit 2 の原因は複数あり、案内先が異なる。

| 原因 | 案内 |
|-----|------|
| playwright・Chromium 未導入（本ケース） | venv 構築（`design-init` / `setup_venv.sh`） |
| 封じ込め違反（`mocksDir` / `assetsDir` がプロジェクトルート外） | `.claude/design-bridge.json` の設定修正 |
| `--only` の空振り | 画面 ID の確認（誤記、またはモックの削除・改名） |

中断が正しい振る舞いである理由は、スクリーンショットが無いまま手順 3 へ進むと、設計書が存在しない画像を参照したまま「反映済み」として扱われうるためである。procedures.md はこれを「安全策なので、無視して続行しない」と明示している。

## 関連ケース

- [case-04_pending_empty.md](case-04_pending_empty.md)（venv が未整備でも、対象 0 件なら `capture.py` を呼ばないため中断に至らない）
- [case-06_partial_push_failure.md](case-06_partial_push_failure.md)（`capture.py` の exit 1 も「失敗分は解除しない」という同じ原則で扱うが、残りで続行するかをユーザーに確認する点が exit 2 と異なる）
- [case-07_auth_error.md](case-07_auth_error.md)（同じく前提不足による中断だが、手順 5 まで進むためローカル側の更新は完了している）
