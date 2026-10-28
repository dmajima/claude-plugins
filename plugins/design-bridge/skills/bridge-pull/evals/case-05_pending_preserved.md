# Case 05: 取り込み後も pending.tsv をクリアしない（bridge-push で整合を取り直す）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「claude.ai/design で直したので取り込んで」 |
| 引数 | なし |
| フラグ | なし（対話モード） |
| 既存状態 | 下記「前提の内訳」のとおり |

### 前提の内訳

| 区分 | 内容 |
|-----|------|
| 設定 | `.claude/design-bridge.json` あり。design-system 認可済み |
| 作業ツリー | クリーン（ローカルの編集はコミット済み。未 push なのは Claude Design に対してである） |
| `last-push.json` | `screens/S001_login.html`（`localPath: mocks/S001_login.html`）を記録。ローカル現物は push 後に編集されており **記録と食い違う** |
| `pending.tsv` | 取り込み前の時点で 2 行。`spec` 種別の `specs/screens/S002_home.md`（設計書を直したが未反映）と、`mock` 種別の `mocks/S001_login.html` |
| リモート | `screens/S001_login.html` が Claude Design 側でも編集されている |
| `block-count` / `dismissed` | `block-count` に `1`。`dismissed` は無い |

`pending.tsv` の実体は次のとおり。

```text
spec	specs/screens/S002_home.md
mock	mocks/S001_login.html
```

## 期待動作

### Phase 1-4: 明示指示の確認から承認まで

- case-01 と同様に進行する。方向確認には分岐せず、作業ツリーの警告も出ない
- 照合では `last-push.json` を基準点として読み、`screens/S001_login.html` が「記録と食い違う」ため `get_file` の対象になる
- 取得内容とローカル現物を比較し、両側が push 後に動いていることを要約して提示する
- 取得内容に指示めいた記述は含まれていない
- ユーザーが取り込み（上書き）を承認する

### Phase 5: 取り込み

- `mocks/S001_login.html` をリモート内容で上書きする
- 設計書（Markdown）は上書きしない。リモートが持つのはモック HTML のみであり、`specs/screens/S002_home.md` には一切触れない

### Phase 6: 整合の取り直し（本ケースの中心）

- 取り込んだモックに対応するスクリーンショットと設計書の画面イメージが古いままになることを認識する
- 書き戻しは Edit/Write で行われるため、PostToolUse フックが `pending.tsv` へ `mock` 種別で `mocks/S001_login.html` を記録する。**スキルが手で追記するのではない**
- `pending.tsv` は追記のみで運用され、重複行の排除は読み取り側が行う。したがって同じパスの行が物理的に 2 行になってもよい（ユニークなパスは 2 件のままである）
- **既存の `spec` 行（`specs/screens/S002_home.md`）を削除しない**
- **`pending.tsv` 自体をクリア・削除しない**
- `clear_pending.sh` を呼ばない（解除は `bridge-push` の責務）
- `block-count` / `dismissed` にも触れない（Stop フックの通知力を弱めない）
- 続けて `bridge-push` を実行し、スクリーンショットの再生成と設計書の画面イメージ更新を行うよう促す

### Phase 7: 報告

- 取り込んだファイル 1 件を報告する
- 未反映がユニークで 2 件（取り込んだモック 1 件 + 既存の設計書 1 件）残っていることを、種別付きで明示する
- 次に必要な操作が `bridge-push` であること、それまでは Stop フックが応答の終了をブロックしうることを伝える

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 更新ファイル | `mocks/S001_login.html` のみ |
| `pending.tsv` | 既存 2 行が残ったまま。フックによる追記で物理行数は増えうるが、`spec` 行は必ず残る |
| 削除・リセットするファイル | なし（`pending.tsv` / `block-count` / `dismissed` / `last-push.json` のいずれも変更しない） |
| `clear_pending.sh` の実行 | 0 回 |
| 標準出力（要約） | 取り込み 1 件、未反映 2 件（`mock` 1 / `spec` 1）、`bridge-push` の案内 |
| 終了状態 | 成功（ただし未反映が残る状態で正常） |

## 分岐の根拠

このケースが分岐するトリガーは 取り込みの完了（Phase 5 の成功） であり、検証対象は実行フロー 6 と重要な制約「取り込み後に未反映記録を解除しない（`bridge-push` での整合取り直しが必要なため）」「`clear_pending.sh` を呼ばない」である。`spec` 種別の既存エントリを前提に置くことで、追記であって置換でもクリアでもないこと、および種別をまたいだ巻き込み解除が起きないことを確認する。

bridge-pull はモック HTML しか取り込まない。取り込んだモックに対応するスクリーンショット（`assetsDir` の PNG）と設計書の画面イメージセクションは古いままであり、整合が取れるのは `bridge-push` を実行した後である。ここで `pending.tsv` をクリアすると、Stop フックが未反映を検出できなくなり、ずれたまま放置される状態が生まれる。

## 関連ケース

- [case-01_interactive_full_scan.md](case-01_interactive_full_scan.md)（`mock` 種別のみの `pending.tsv` に対する追記。本ケースは `spec` 種別の既存エントリの保持を追加で検証する）
- [case-03_non_interactive_path.md](case-03_non_interactive_path.md)（非対話モードでも Phase 6 の扱いは同じく適用される）
- [case-07_injected_content_quarantine.md](case-07_injected_content_quarantine.md)（検疫して取り込まなかったファイルは書き戻しが起きないため、`pending.tsv` にも記録されない）
