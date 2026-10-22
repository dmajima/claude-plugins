# Case 03: `--all` 指定（全モック対象・削除候補の確認）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「全部まとめて Claude Design に反映して」 |
| 引数 | `--all` |
| フラグ | `--all`（引数指定により非対話モード） |
| 既存状態 | `.claude/design-bridge.json` あり。認可済み・venv 構築済み。`mocksDir` に `_tokens.html` `_layout.html` `S001_login.html` `S002_home.html` の 4 件。リモートには加えて `screens/S900_old.html` が存在し、ローカルには対応ファイルが無い |

## 期待動作

### Phase 1: 導入確認と対象決定
- `--all` が指定されているため、対象決定表により `mocksDir` 配下の全モック 4 件を対象とする
- `pending.txt` の内容は対象決定に使わない（空であっても `--all` では空振り終了しない）

### Phase 2: スクリーンショットの再生成
- `capture.py` を `--only` なしで `Bash` ツール経由で起動し、全件を撮影する
- 部品（`_tokens.html` 等）を除外する場合は `--skip-partials` を付ける

### Phase 3: Markdown の画面イメージ更新
- 対応する設計書が存在する画面について、画面イメージセクションを更新する

### Phase 4: バンドルの作成
- バンドルを作り直す
- アンダースコア始まりの `_tokens.html` `_layout.html` を `foundations/` へ、それ以外を `screens/` へ配置する
- 各 HTML の先頭行に `@dsCard` マーカーが無ければ付与する（`foundations/` 側は `group="Foundations"` 相当）

### Phase 5: DesignSync による push と削除確認
- `get_project` で design-system 型を確認する
- `list_files` の結果とバンドルを突き合わせ、追加 / 更新 / 削除を判定する
- リモートのみに存在する `screens/S900_old.html` を **削除候補** として検出する
- 削除候補はローカルで意図的に消したものか、Claude Design 側で別経路に追加されたものかを区別できないため、**削除してよいかを必ずユーザーに確認する**
- ユーザーが削除を承認しなかった場合は `deletes` から除外し、`writes` のみで計画を確定する
- 加えて、リモートにローカルが知らないファイルが含まれていたことから、上書き前に `design-status` または `design-pull` での確認を提案する
- `finalize_plan`（`writes` / 承認された `deletes` / `localDir`）→ `write_files`（`localPath` 指定）の順で実行する。削除がある場合は同じ `planId` で `delete_files` を呼ぶ
- 対象が 256 ファイルを超える場合は同一 `planId` で複数回に分割する

### Phase 6: 未反映記録のクリア
- push が完全に成功したことを確認したうえで、`pending.txt` と `block-count` を削除する

### Phase 7: 報告
- 反映したカード一覧、削除の扱い（承認 / 見送り）、リモート先行の疑いがある旨を提示する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの確認 | 2 回以上（push 計画の提示、削除候補 `screens/S900_old.html` の可否確認） |
| 生成ファイル | 全モックのスクリーンショット、バンドル内 `foundations/` 2 件 + `screens/` 2 件 |
| 削除ファイル | `pending.txt`、`block-count`（push 成功時のみ） |
| 標準出力（要約） | 反映カード 4 件、削除候補の扱い、`design-pull` での確認提案 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは 引数 = `--all` である。対象決定表により対象が `pending.txt` ではなく `mocksDir` 配下の全モックになる。加えて `list_files` の結果に削除候補が含まれる点が、削除確認フローを発火させる第二のトリガーになっている。

## 関連ケース

- [case-01_pending_all.md](case-01_pending_all.md)（対象が `pending.txt` 全件に限られ、`mocksDir` の未変更モックは対象外になる点が対照的）
- [case-02_screen_id.md](case-02_screen_id.md)（同じ非対話モードだが対象が 1 画面に限定される）
- [case-04_pending_empty.md](case-04_pending_empty.md)（`pending.txt` が空でも `--all` なら空振り終了しない点が対照的）
