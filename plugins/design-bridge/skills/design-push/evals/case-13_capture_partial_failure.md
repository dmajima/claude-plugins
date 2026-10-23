# Case 13: capture.py が exit 1（一部のモックで撮影失敗・続行可否を確認）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「Claude Design に反映して」 |
| 引数 | なし |
| フラグ | なし（対話モード） |
| 既存状態 | `.claude/design-bridge.json` あり（design-system 型）。認可済み・venv 構築済み。`pending.tsv` は次の 4 行。`capture.py` は `S001_login` の撮影に成功し、`S002_home` で失敗して **exit 1** を返す |

```text
mock	mocks/S001_login.html
spec	specs/screens/S001_login.md
mock	mocks/S002_home.html
spec	specs/screens/S002_home.md
```

## 期待動作

### Phase 1: 導入確認と対象決定
- 引数が無いため対象は `pending.tsv` の全件（モック 2 件・設計書 2 件）。対象集合として記録する

### Phase 2: capture.py が exit 1
- `Bash` ツール経由で `capture.py` を `--only "S001_login" --only "S002_home"` で起動する
- `capture.py` は 1 件の失敗で全体を止めず、残りの撮影を続けたうえで終了コード 1 を返す

```text
生成: S001_login.png <- S001_login.html
失敗: S002_home.html (<例外クラス>: <詳細>)      ← 標準エラー
完了: 成功 1 件 / 失敗 1 件
失敗したファイル: S002_home.html                 ← 標準エラー
```

- 終了コード表の「1 = 1 件以上失敗 → 失敗したモックを報告し、残りで push を続けるかユーザーに確認。失敗分は未反映記録を解除しない」に該当する
- **exit 1 を exit 0 と同じに扱わない。** 失敗を無視して 4 件すべてを対象のまま進めない
- 失敗した画面には新しい PNG が書かれない。過去の実行で生成された古い PNG が残っている場合があるが、**それを「撮影成功」とみなさない**

### Phase 2.5: 続行可否をユーザーに確認（本ケースの中心）
- 失敗したモック（`mocks/S002_home.html`）と、`capture.py` が出力した失敗理由を提示する
- **「成功した `S001_login` だけで push を続けるか、それとも中止するか」をユーザーに確認する**
- Claude の判断だけで続行・中止を決めない。exit 1 は終了コード表の 3 分岐のうち唯一、判断をユーザーに委ねる値である
- 非対話モードでの扱いは SKILL.md・procedures.md に規定が無い。本ケースは対話モードに限定して定義する

以降は回答によって 2 つに分かれる。

### 分岐 A: 続行を選んだ場合

#### Phase 3: Markdown の画面イメージ更新（対象を縮小）
- `specs/screens/S001_login.md` の画面イメージセクションのみ更新する
- **`specs/screens/S002_home.md` は更新しない。** スクリーンショットが無い（または古い）状態で画像参照だけ更新すると、実体と食い違う画像を指す設計書が残る。case-09 で exit 2 のときに更新しないのと同じ理由である

#### Phase 4: バンドルの作成
- バンドルを作り直し、`screens/S001_login.html` のみを配置する
- `screens/S002_home.html` をバンドルに入れない（**失敗した画面を以降の対象から外す**）

#### Phase 5: DesignSync による push
- `get_project` → `list_files` → 計画提示 → 承認 → `finalize_plan` → `write_files`
- 計画は `screens/S001_login.html` の 1 件。承認を得て送信し、成功する

#### Phase 6: push マニフェストの更新
- `screens/S001_login.html` のエントリ（`sha256` と `localPath: mocks/S001_login.html`）のみを `last-push.json` に記録する
- `screens/S002_home.html` は push していないため記録しない

#### Phase 7: 成功分だけを `--path` で解除

```bash
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/hooks/clear_pending.sh" \
  --project-root "<プロジェクトルート>" \
  --path "mocks/S001_login.html" \
  --path "specs/screens/S001_login.md"
```

- **`--all --drop-bundle` を使わない。** 対象集合は `pending.tsv` 全件だが、全件を反映できていない
- `S002_home` のモックと設計書の 2 行を `pending.tsv` に残す（**記録も解除しない**）
- 残存が 0 件ではないため `block-count` は削除されない
- `bundle/` は削除しない（再試行に使う）

#### Phase 8: 報告
- 撮影成功 1 件・失敗 1 件、push 成功 1 件を区別して提示する
- 解除 2 件・残存 2 件を明示し、`S002_home` が未反映のまま残っていることを伝える
- 失敗理由と、解消後に画面 ID を指定して再実行できることを案内する
- 全体として「反映しました」とは報告しない（部分完了として報告する）

### 分岐 B: 中止を選んだ場合

#### Phase 3 以降: 実行しない
- **いずれの設計書も更新しない**（`S001_login` の画面イメージも更新しない）
- バンドルを作成しない
- **`DesignSync` を一切呼び出さない**（`get_project` も含む）
- `last-push.json` を更新しない
- **`clear_pending.sh` を呼び出さない。** `pending.tsv` の 4 行をそのまま残す。`block-count` と `dismissed` も変更しない

#### Phase 8: 報告
- ユーザーの判断により **何も push していない** ことを明示する
- 成功した `specs/assets/S001_login.png` は既に再生成されており、ローカル側の副作用として残っていることを伝える
- 失敗理由を提示し、解消後に再実行すれば 4 件がそのまま対象になることを伝える

## 期待出力

### 分岐 A（続行）

| 項目 | 期待値 |
|-----|-------|
| ユーザへの確認 | 2 回（撮影失敗時の続行可否、push 計画の提示） |
| 外部呼び出し | `capture.py` 1 回（exit 1）、`get_project` / `list_files` / `finalize_plan` / `write_files` 各 1 回、`clear_pending.sh` 1 回 |
| 生成ファイル | `specs/assets/S001_login.png`、`bundle/screens/S001_login.html`、`last-push.json`（`S001_login` の 1 件のみ） |
| 更新ファイル | `specs/screens/S001_login.md` の画面イメージセクションのみ |
| 更新しないファイル | `specs/screens/S002_home.md`（画像参照を更新しない） |
| 残存ファイル | `pending.tsv`（`S002_home` の 2 行が残る）、`block-count`（あれば保持）、`bundle/` |
| `clear_pending.sh` の出力 | `解除: 2 件 / 残存: 2 件` |
| 標準出力（要約） | 撮影 成功 1 / 失敗 1、push 成功 1 件、解除 2 件・残存 2 件、失敗理由と再実行の案内 |
| 終了状態 | 部分完了（成功とも全体失敗とも報告しない） |

### 分岐 B（中止）

| 項目 | 期待値 |
|-----|-------|
| ユーザへの確認 | 1 回（撮影失敗時の続行可否。結果は中止） |
| 外部呼び出し | `capture.py` 1 回（exit 1）のみ。`DesignSync` 0 回、`clear_pending.sh` 0 回 |
| 生成ファイル | `specs/assets/S001_login.png`（撮影済みの分のみ）。`bundle/` は作られない |
| 更新ファイル | なし（設計書・`last-push.json` とも変更しない） |
| 残存ファイル | `pending.tsv`（4 行のまま）、`block-count`・`dismissed`（あれば保持） |
| `clear_pending.sh` の呼び出し | 0 回 |
| 標準出力（要約） | 何も push していないこと、`S001_login.png` は再生成済みであること、失敗理由と再実行の案内 |
| 終了状態 | 中断（ユーザー判断による。未反映のまま） |

## 撮影失敗の原因と案内

`capture.py` は安全性のための制限下で描画するため、制限に抵触するモックは画像化できない。原因に応じて案内が変わる。

| 原因 | 根拠となる制限 | 案内 |
|-----|--------------|------|
| 外部 CDN に依存している | `mocksDir` 配下以外への要求を中断する | 外部依存を外す（`design-mock` が生成するモックは最初から外部依存を持たない方針） |
| JavaScript で描画している | JavaScript を無効化している | 静的 HTML として描画できる形にする |
| 読み込みが終わらない | `--timeout-ms`（既定 10000）を超えた | モックを軽量化する、または時間をおいて再実行する |

いずれの場合も **描画時の制限を外して解決しない。** procedures.md は「いずれも安全性のための措置であり、『モックが思ったように描画されない』という理由で外さない」と明示している。

## 分岐の根拠

このケースが分岐するトリガーは `capture.py` の終了コード = 1 である。procedures.md の終了コード表が定める 3 分岐のうち、**唯一ユーザーへの確認を挟む値** である。

| 終了コード | 意味 | 対応 | ケース |
|---|------|------|-------|
| 0 | 全件成功（対象 0 件を含む） | 確認なしで続行 | case-01 / case-02 / case-03 |
| 1 | 1 件以上失敗 | 失敗を報告し、残りで push を続けるかユーザーに確認。失敗分は解除しない | **本ケース** |
| 2 | 引数エラー / 封じ込め違反 / playwright・Chromium 未導入 / `--only` の空振り | 確認なしで中断 | case-09 / case-12 |

続行を選んだ場合に失敗分を対象から外す理由は 2 つある。第 1 に、スクリーンショットが無いまま設計書の画像参照だけ更新すると、存在しない（または古い）画像を指す設計書が残る。第 2 に、反映していないものの記録を解除すると「反映済みのつもりで未反映」の状態になり、Stop フックの検出対象から外れる。どちらも design-bridge が防ごうとしている失敗そのものである。

中止を選んだ場合に何も push しないのは、ユーザーが「この状態では反映しない」と判断したためであり、計画拒否（case-10）と同じく失敗ではない。

## エッジケース

| 状況 | 動作 |
|-----|------|
| 全件が失敗した（成功 0 件） | 終了コードは 1 のまま。続行を選んでも push 対象が無いため中止と同じ帰結になり、記録も解除しない |
| 成功・失敗の切り分けができない | 全体失敗として扱い、一切解除しない（procedures.md「迷った場合は解除しない側に倒す」） |
| 失敗した画面だけを後から反映したい | 原因解消後、画面 ID を引数に指定して再実行する（case-02 の経路） |
| `--only` で指定した画面が存在しない | exit 1 ではなく exit 2（空振り）。確認を挟まず中断する |
| 続行後に `write_files` も一部失敗した | 撮影成功かつ push 成功したものだけを `--path` で解除する（case-06 と同じ原則） |

## 関連ケース

- [case-09_screenshot_venv_missing.md](case-09_screenshot_venv_missing.md)（同じ `capture.py` 起点だが exit 2 のため確認を挟まず中断する）
- [case-12_capture_containment_violation.md](case-12_capture_containment_violation.md)（同じく exit 2 の中断。原因が封じ込め違反である）
- [case-06_partial_push_failure.md](case-06_partial_push_failure.md)（同じ「成功分のみ `--path` で解除」だが、失敗が起きる位置が手順 5 である）
- [case-01_pending_all.md](case-01_pending_all.md)（exit 0 なら確認なしで全件続行し、`--all --drop-bundle` で解除できる）
- [case-10_plan_rejected.md](case-10_plan_rejected.md)（分岐 B と同じく何も push しないが、中止の判断が計画提示の段階で行われる）
