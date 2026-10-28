# Case 02: 画面 ID 指定（非対話モード・部分解除）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「S002_home だけ Claude Design に反映して」 |
| 引数 | `S002_home` |
| フラグ | なし（引数で対象を指定しているため非対話モード） |
| 既存状態 | `.claude/design-bridge.json` あり（design-system 型）。認可済み・venv 構築済み。`pending.tsv` に 4 行あり、ユーザーは `S002_home` だけを指定している |

```text
mock	mocks/S001_login.html
spec	specs/screens/S001_login.md
mock	mocks/S002_home.html
spec	specs/screens/S002_home.md
```

## 期待動作

### Phase 1: 導入確認と対象決定
- 引数で画面 ID が指定されているため、実行モード判定表により非対話モードとして進行する
- 対象決定表により、対象は `S002_home` の設計書・モックのみとする
- **対象集合は `mocks/S002_home.html` と `specs/screens/S002_home.md` の 2 件。** `S001_login` の 2 件は `pending.tsv` に記録されていても対象に含めない
- 対象が `pending.tsv` の部分集合であることを認識する（Phase 7 の解除方法を決める判断材料）

### Phase 2: スクリーンショットの再生成
- `capture.py` を `--project-root` 必須引数付き、`--only "S002_home"` で `Bash` ツール経由から起動する
- 対象外の `S001_login` のスクリーンショットは再生成しない
- 終了コード 0 を確認して続行する。`--only` が空振りして exit 2 になった場合は中断する（case-09 の分岐）

### Phase 3: Markdown の画面イメージ更新
- `specs/screens/S002_home.md` の画面イメージセクションのみ更新する
- `specs/screens/S001_login.md` には触れない

### Phase 4: バンドルの作成
- バンドルを作り直し、`screens/S002_home.html` のみを配置する
- `@dsCard` マーカーが無ければ付与する

### Phase 5: DesignSync による push
- `get_project` → `list_files` の順で読み取り、追加 / 更新 / 削除を判定する
- **非対話モードでも push 計画の提示は省略しない。** 対象 1 件の計画を提示する
- `finalize_plan` → `write_files`（`localPath` 指定）の順で送る。成功

### Phase 6: push マニフェストの更新
- `last-push.json` に `screens/S002_home.html` のエントリ（`sha256` と `localPath: mocks/S002_home.html`）と `pushedAt` を記録する
- 部分 push のときに既存エントリをどう扱うか（マージか置換か）は SKILL.md・procedures.md に規定が無い。本ケースで確認するのは「push に成功した 1 件が `last-push.json` に記録されていること」までとする

### Phase 7: 未反映記録の部分解除（本ケースの中心）
- 解除範囲の表の「画面 ID 指定で成功」に該当するため、その画面の設計書とモックのみを `--path` で列挙する

```bash
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/hooks/clear_pending.sh" \
  --project-root "<プロジェクトルート>" \
  --path "mocks/S002_home.html" \
  --path "specs/screens/S002_home.md"
```

- **`--all` を使わない。** 使うと対象外の `S001_login` の記録まで巻き込んで消える
- `--drop-bundle` も使わない（全件反映ではないため）
- `pending.tsv` は削除されず、`S001_login` の 2 行が残る
- 残存が 0 件ではないため、`clear_pending.sh` は `block-count` を削除しない
- `pending.tsv` を直接編集しない

### Phase 8: 報告
- 反映したカード（`screens/S002_home.html`）と、未反映のまま残った 2 件（`mocks/S001_login.html` / `specs/screens/S001_login.md`）を明示する
- 残りを反映するには引数なしで再実行すればよいことを案内する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの確認 | push 計画の提示（非対話モードでも省略しない） |
| 生成ファイル | `specs/assets/S002_home.png`、バンドル内 `screens/S002_home.html`、`last-push.json` |
| 更新ファイル | `specs/screens/S002_home.md` の画面イメージセクションのみ |
| 残存ファイル | `pending.tsv`（`S001_login` の 2 行が残る）、`block-count`（あれば保持） |
| `clear_pending.sh` の出力 | `解除: 2 件 / 残存: 2 件` |
| 標準出力（要約） | 反映 1 件、未反映として残った 2 件の明示、再実行の案内 |
| 終了状態 | 成功（部分反映） |

## 分岐の根拠

このケースが分岐するトリガーは 引数 = 画面 ID である。実行モード判定表の「引数で対象を指定」に該当して非対話モードになり、対象決定表の「引数で画面 ID 指定」に該当して対象が当該画面に限定される。

その結果、**対象集合が `pending.tsv` の部分集合**になり、解除方法が case-01 の `--all --drop-bundle` から `--path` の列挙に変わる。SKILL.md の重要な制約「対象が `pending.tsv` の部分集合のときは、対象外のエントリを残したまま該当分のみ解除する」を直接検証するケースである。

## 関連ケース

- [case-01_pending_all.md](case-01_pending_all.md)（引数なしなら対話モードかつ対象 = `pending.tsv` 全件になり、解除が `--all --drop-bundle` になる）
- [case-03_all_mocks.md](case-03_all_mocks.md)（同じ非対話モードだが対象が `mocksDir` 配下の全モックになり、解除は push したモックと更新した設計書の列挙になる）
- [case-06_partial_push_failure.md](case-06_partial_push_failure.md)（同じ `--path` による部分解除だが、部分集合になる原因が引数ではなく push の一部失敗である点が異なる）
