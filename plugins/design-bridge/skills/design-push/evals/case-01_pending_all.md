# Case 01: 引数なし（pending.txt 全件・対話モード）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「Claude Design に反映して」 |
| 引数 | なし |
| フラグ | なし（対話モード） |
| 既存状態 | `.claude/design-bridge.json` あり（`projectId` は design-system 型）。design-system 認可済み。スクショ用 venv 構築済み。`pending.txt` に `mocks/S001_login.html` と `specs/screens/S001_login.md` の 2 行。リモートには同名カードが既に存在する |

## 期待動作

### Phase 1: 導入確認と対象決定
- `.claude/design-bridge.json` を読み、`specsDir` / `assetsDir` / `mocksDir` / `viewport` を得る
- 引数が無いため、対象は `.claude/.local/plugins/design-bridge/pending.txt` の全件とする
- `pending.txt` が非空のため、空振り終了（case-04）には進まない
- 設計書とモックの両方が記録されているが、スクショ生成の対象は画面 ID `S001_login` のモック 1 件に集約される

### Phase 2: スクリーンショットの再生成
- `Bash` ツール経由で `capture.py` を起動する（`PowerShell` ツールからの直接起動はハング既知事象のため行わない）
- `--mocks-dir <mocksDir> --out-dir <assetsDir> --width 1280 --height 800 --only S001_login` を渡す
- 終了コード 0 を確認して続行する

### Phase 3: Markdown の画面イメージ更新
- `specs/screens/S001_login.md` の「画面イメージ」セクションのみを更新する（無ければ画面概要の直後に挿入）
- 画像参照とモックへのリンク、Design カード名を設計書の位置から解決できる相対パスで書く
- 画面イメージセクション以外の本文は書き換えない

### Phase 4: バンドルの作成
- `.claude/.local/plugins/design-bridge/bundle/` を作り直す（古い残骸を持ち越さない）
- `S001_login.html` を `screens/` 配下へ配置する
- 先頭行に `<!-- @dsCard group="..." -->` が無ければ付与する。`register_assets` は呼ばない

### Phase 5: DesignSync による push
- `get_project` で `type` が design-system であることを確認する
- `list_files` でリモート構成を取得し、追加 / 更新 / 削除を判定する（本ケースは更新 1 件、削除なし）
- push 計画をユーザーに提示し、承認を得る
- `finalize_plan` で `writes` と `localDir`（バンドルの絶対パス）を確定し、`planId` を得る
- `write_files` を `localPath` 指定で呼ぶ（HTML 本文をコンテキストに載せない）

### Phase 6: 未反映記録のクリア
- push が完全に成功したことを確認したうえで、`pending.txt` と `block-count` を削除する

### Phase 7: 報告
- 反映したカード、生成したスクリーンショット、更新した設計書、Claude Design プロジェクト名を提示する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの確認 | 1 回以上（push 計画の提示と承認） |
| 生成ファイル | `specs/assets/S001_login.png`（再生成）、`.claude/.local/plugins/design-bridge/bundle/screens/S001_login.html` |
| 更新ファイル | `specs/screens/S001_login.md` の画面イメージセクションのみ |
| 削除ファイル | `.claude/.local/plugins/design-bridge/pending.txt`、`.claude/.local/plugins/design-bridge/block-count` |
| 標準出力（要約） | 反映したカード一覧（`screens/S001_login.html`）と Claude Design プロジェクト名を含む報告 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは 引数 = なし かつ `pending.txt` = 非空 である。実行モード判定表により引数指定も `--non-interactive` も無いため対話モードとなり、対象決定表により `pending.txt` の全件が対象になる。

## 関連ケース

- [case-02_screen_id.md](case-02_screen_id.md)（引数で画面 ID を与えると非対話モードになり、対象が `pending.txt` ではなく指定画面に決まる点が対照的）
- [case-04_pending_empty.md](case-04_pending_empty.md)（同じ引数なしでも `pending.txt` が空なら push せず正常終了する）
- [case-05_push_failure.md](case-05_push_failure.md)（Phase 5 が失敗した場合、Phase 6 のクリアを行わない）
