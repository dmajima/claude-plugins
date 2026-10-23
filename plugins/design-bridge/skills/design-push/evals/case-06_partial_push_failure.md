# Case 06: write_files が一部失敗（成功分のみ `--path` で解除）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「Claude Design に反映して」 |
| 引数 | なし |
| フラグ | なし（対話モード） |
| 既存状態 | `.claude/design-bridge.json` あり（design-system 型）。認可済み・venv 構築済み。`pending.tsv` は次の 4 行。`write_files` のうち `screens/S001_login.html` は成功し、`screens/S002_home.html` が失敗する |

```text
mock	mocks/S001_login.html
spec	specs/screens/S001_login.md
mock	mocks/S002_home.html
spec	specs/screens/S002_home.md
```

## 期待動作

### Phase 1-4: 対象決定からバンドル作成まで
- 引数が無いため対象は `pending.tsv` 全件（モック 2 件・設計書 2 件）。対象集合として記録する
- `capture.py` を `--only "S001_login" --only "S002_home"` で起動し、終了コード 0 を確認する
- 両方の設計書の画面イメージセクションを更新する
- バンドルを作り直し、`screens/S001_login.html` と `screens/S002_home.html` を配置する

### Phase 5: DesignSync による push（一部失敗）
- `get_project` → `list_files` → 計画提示 → 承認 → `finalize_plan` で `planId` を得る
- `write_files` を `localPath` 指定で呼ぶ
- `screens/S001_login.html` は成功、`screens/S002_home.html` は失敗する
- **成功したパスと失敗したパスを明確に区別する。** 区別できない場合は「全体失敗」として扱い、一切解除しない（case-05 の扱いへ倒す）

### Phase 6: push マニフェストの更新
- 成功した `screens/S001_login.html` のエントリ（`sha256` と `localPath: mocks/S001_login.html`）のみを `last-push.json` に記録する
- 失敗した `screens/S002_home.html` は記録しない（リモートに存在しないものを基準点にしない）

### Phase 7: 成功分だけを `--path` で解除（本ケースの中心）
- 解除範囲の表の「一部失敗 → 成功したものだけを `--path` で列挙」に該当する

```bash
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/hooks/clear_pending.sh" \
  --project-root "<プロジェクトルート>" \
  --path "mocks/S001_login.html" \
  --path "specs/screens/S001_login.md"
```

- **`--all --drop-bundle` を使わない。** 対象集合は `pending.tsv` 全件だが、全件成功していないため条件を満たさない
- 失敗した `S002_home` のモックと設計書の 2 行は `pending.tsv` に残す
- `bundle/` は削除しない（再試行に使うため `--drop-bundle` を付けない）
- 残存が 0 件ではないため `block-count` は削除されない

### Phase 8: 報告
- 成功 1 件・失敗 1 件を区別して提示する
- 解除 2 件・残存 2 件を明示し、`S002_home` が未反映のまま残っていることを伝える
- 失敗原因に応じた再実行を案内する。再実行時は `S002_home` だけを引数指定すれば対象を絞れることを添える
- 全体として「反映しました」とは報告しない（部分完了として報告する）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの確認 | push 計画の提示と承認 |
| 生成ファイル | `specs/assets/S001_login.png`・`specs/assets/S002_home.png`、バンドル内 HTML 2 件 |
| 更新ファイル | 両方の設計書の画面イメージセクション、`last-push.json`（成功した 1 件のみ） |
| 残存ファイル | `pending.tsv`（`S002_home` の 2 行が残る）、`block-count`（あれば保持）、`bundle/` |
| `clear_pending.sh` の出力 | `解除: 2 件 / 残存: 2 件` |
| 標準出力（要約） | 成功 1 件・失敗 1 件の内訳、解除 2 件・残存 2 件、再実行の案内 |
| 終了状態 | 部分完了（成功とも全体失敗とも報告しない） |

## 分岐の根拠

このケースが分岐するトリガーは `write_files` の結果 = 一部成功・一部失敗 である。case-05（全件失敗 → 一切解除しない）と同じ `write_files` の失敗でありながら、解除動作が「0 件解除」から「成功分のみ解除」へ変わる点が分岐の核心である。

ここで全件を解除すると失敗分が未反映のまま見えなくなり、逆に 1 件も解除しないと反映済みの変更が Stop フックで通知され続ける。どちらも誤りであるため、成功・失敗の切り分けが解除範囲の決定に直結する。切り分けできない場合に case-05 側（解除しない）へ倒すのは、procedures.md の「迷った場合は解除しない側に倒す」に従う。

なお、スクリーンショット生成が一部失敗した場合（`capture.py` の exit 1）も同じ原則が適用され、失敗した画面は解除しない。ただし分岐点が手順 5 ではなく手順 2 である点が異なる。

## 関連ケース

- [case-05_push_failure.md](case-05_push_failure.md)（全件失敗のため 1 件も解除しない。切り分け不能時もこちらへ倒す）
- [case-02_screen_id.md](case-02_screen_id.md)（同じ `--path` による部分解除だが、部分集合になる原因が引数指定である点が異なる）
- [case-01_pending_all.md](case-01_pending_all.md)（同じ対象集合でも全件成功なら `--all --drop-bundle` が使える）
