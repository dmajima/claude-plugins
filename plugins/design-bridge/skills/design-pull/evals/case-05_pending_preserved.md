# Case 05: 取り込み後に pending.txt をクリアしない

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「claude.ai/design で直したので取り込んで」 |
| 引数 | なし |
| フラグ | なし（対話モード） |
| 既存状態 | `.claude/design-bridge.json` あり。design-system 認可済み。作業ツリーはクリーン。**取り込み前の時点で `pending.txt` に既存エントリ `specs/screens/S002_home.md` が 1 行ある**（ローカルで設計書を直したが未反映の状態）。リモートでは `screens/S001_login.html` が更新されている |

## 期待動作

### Phase 1-4: 明示指示の確認から承認まで
- case-01 と同様に進行する
- 方向確認には分岐せず、作業ツリーの警告もなく、全件照合で `S001_login.html` のリモート先行を検出する
- 差分を要約提示し、ユーザーが取り込みを承認する

### Phase 5: 取り込み
- `mocks/S001_login.html` をリモート内容で上書きする
- 設計書（Markdown）は上書きしない。リモートが持つのはモック HTML のみであり、`specs/screens/S002_home.md` には一切触れない

### Phase 6: 整合の取り直し（本ケースの中心）
- 取り込んだモックに対応するスクリーンショットと設計書が古いままになることを認識する
- 取り込んだパス `mocks/S001_login.html` を `pending.txt` に **追記** する
- **既存エントリ `specs/screens/S002_home.md` を削除しない**
- **`pending.txt` 自体をクリア・削除しない**
- `block-count` にも触れない（Stop フックの強制力を弱めない）
- 結果として `pending.txt` は 2 行（既存 1 件 + 追記 1 件）になる
- 続けて `design-push` を実行し、スクリーンショットの再生成と設計書の画面イメージ更新を行うよう促す

### Phase 7: 報告
- 取り込んだファイル 1 件を報告する
- 未反映が 2 件（取り込み分 1 件 + 既存 1 件）残っていることを明示する
- 次に必要な操作が `design-push` であること、それまでは Stop フックが応答の終了をブロックしうることを伝える

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 更新ファイル | `mocks/S001_login.html` のみ |
| `pending.txt` の内容 | 既存の `specs/screens/S002_home.md` と、追記された `mocks/S001_login.html` の 2 行 |
| 削除ファイル | なし（`pending.txt` も `block-count` も削除しない） |
| 標準出力（要約） | 取り込み 1 件、未反映 2 件、`design-push` の案内 |
| 終了状態 | 成功（ただし未反映が残る状態で正常） |

## 分岐の根拠

このケースが分岐するトリガーは 取り込みの完了（Phase 5 の成功） であり、検証対象は実行フロー 6 と重要な制約「取り込み後に `pending.txt` をクリアしない（`design-push` での整合取り直しが必要なため）」である。既存エントリがある状態を前提に置くことで、「追記」であって「置換」でも「クリア」でもないことを確認する。

design-pull はモック HTML しか取り込まない。取り込んだモックに対応するスクリーンショット（`assetsDir` の PNG）と設計書の画面イメージセクションは古いままであり、整合が取れるのは `design-push` を実行した後である。ここで `pending.txt` をクリアすると、Stop フックが未反映を検出できなくなり、ずれたまま放置される状態が生まれる。

## 関連ケース

- [case-01_interactive_full_scan.md](case-01_interactive_full_scan.md)（`pending.txt` に既存エントリが無い状態での追記。本ケースは既存エントリの保持を追加で検証する）
- [case-03_non_interactive_path.md](case-03_non_interactive_path.md)（非対話モードでも Phase 6 の追記とクリア禁止は同じく適用される）
