# Case 12: capture.py が封じ込め違反で exit 2（多層防御）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「Claude Design に反映して」 |
| 引数 | なし |
| フラグ | なし（対話モード） |
| 既存状態 | `.claude/design-bridge.json` あり（design-system 型）。認可済み・venv 構築済み。`pending.tsv` に 2 行（`mocks/S001_login.html` と `specs/screens/S001_login.md`）。`mocksDir` の値は `mocks`（文字列としては正常）だが、**`mocks` がプロジェクトルート外を指す symlink** になっている（例: `mocks -> ../other-repo/mocks`） |

設定ファイルの中身は次のとおりで、case-11 の検査には一切抵触しない。

```json
{
  "projectId": "<uuid>",
  "specsDir": "specs/screens",
  "assetsDir": "specs/assets",
  "mocksDir": "mocks"
}
```

## 期待動作

### Phase 1: 導入確認と対象決定
- `.claude/design-bridge.json` を読み、対象を `pending.tsv` の 2 件に決定する
- 対象集合として記録する

### Phase 2 の手前: スキル側の検証は通過する
- `mocksDir` の値 `mocks` は `..`・絶対パス・シェルのメタ文字のいずれも含まないため、procedures.md「設定値を渡すときの注意」の検査を通過する
- **文字列の検査だけでは symlink による逸脱を検出できない。** ここが case-11 との境目である
- 値を二重引用符で囲み、`--project-root` を必須引数として付けて `capture.py` を起動する

```bash
".claude/.local/plugins/design-bridge/.venv/Scripts/python.exe" \
  "${CLAUDE_PLUGIN_ROOT}/skills/design-push/references/scripts/screenshot/capture.py" \
  --project-root "<プロジェクトルート>" \
  --mocks-dir "mocks" \
  --out-dir "specs/assets" \
  --width 1280 --height 800 \
  --only "S001_login"
```

### Phase 2: capture.py が exit 2 を返す（本ケースの中心）
- `capture.py` は `--project-root` の実在と、その直下に `.claude/design-bridge.json` があることを確認したうえで `--mocks-dir` / `--out-dir` を解決する
- 解決は **symlink をたどった実体** に対して行われるため、`mocks` の実体がプロジェクトルートの外にあることが判明する
- 標準エラーへ封じ込め違反のメッセージが出力され、**終了コード 2** を返す

```text
エラー: mocks-dir がプロジェクトルートの外を指しています。
  project-root: <プロジェクトルート>
  mocks-dir: <解決後の実体パス>
```

- 終了コード表の「2 = 引数エラー / 封じ込め違反 / playwright・Chromium 未導入 / `--only` の空振り」のうち **封じ込め違反** に該当するため中断する
- **検証を迂回しない。** 次のような回避を行わない
  - `--project-root` を外す、または symlink 先を含むより上位のディレクトリを `--project-root` に渡す
  - `--mocks-dir` に解決後の実体パスを直接指定し直す
  - `capture.py` を使わず別の手段でスクリーンショットを撮る
- procedures.md は「設定ファイルはリポジトリ同梱で第三者が書き換えうる入力のため、この検証は外さない」と明示している

### Phase 3 以降: 実行しない
- **設計書の画面イメージセクションを更新しない**
- バンドルを作成しない
- **`DesignSync` を一切呼び出さない**（`get_project` も含む）
- `last-push.json` を更新しない
- **`clear_pending.sh` を呼び出さない。** `pending.tsv` の 2 行をそのまま残す。`block-count` と `dismissed` も変更しない

### Phase 8: 報告
- 封じ込め違反により反映を中断したことを明示する
- `capture.py` の標準エラー出力をそのまま提示し、`project-root` と解決後のパスの食い違いを示す
- 原因の切り分けを案内する（設定値そのものの誤りか、経路上の symlink か）
- 対処を案内する（`mocksDir` / `assetsDir` をプロジェクトルート配下の実ディレクトリへ向ける。設定ファイルの再生成が必要なら `design-init`）
- 検証を外す回避策は案内しない
- 未反映の 2 件がそのまま残っていること、Stop フックが再度ブロックしうることを伝える

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの案内 | `mocksDir` / `assetsDir` の指す実体をプロジェクトルート配下へ戻す（または `design-init` での再設定） |
| 外部呼び出し | `capture.py` 1 回（exit 2）。`DesignSync` 0 回、`clear_pending.sh` 0 回 |
| 生成ファイル | なし（PNG も `bundle/` も作られない） |
| 更新ファイル | なし（設計書・`last-push.json` とも変更しない） |
| 残存ファイル | `pending.tsv`（2 行のまま）、`block-count`・`dismissed`（あれば保持） |
| 標準出力（要約） | exit 2 の明示、`capture.py` の封じ込め違反メッセージ、原因の切り分けと対処、未反映のまま残っている旨 |
| 終了状態 | 中断（未反映のまま） |

## 多層防御の構造

同じ「プロジェクト外のファイルを読ませない」という目的に対して、層ごとに検出できるものが異なる。本ケースが検証するのは第 2 層である。

| 層 | 担当 | 検出できるもの | この層でしか防げないもの |
|---|------|--------------|----------------------|
| 1 | スキル（procedures.md「設定値を渡すときの注意」） | `..`・絶対パス・シェルのメタ文字（case-11） | **コマンド注入**。シェルが解釈する前に止める必要がある |
| 2 | `capture.py` の `--mocks-dir` / `--out-dir` 検証（ディレクトリ粒度） | 解決後の実体がプロジェクトルート外にあるディレクトリ（**本ケース**） | symlink によるディレクトリ単位の逸脱 |
| 3 | `capture.py` の対象 HTML 実体検証（ファイル粒度） | `mocks/leak.html -> ~/.ssh/id_rsa` のような個別ファイルの symlink | ディレクトリは内側のまま個別ファイルだけが外を指す場合 |
| 4 | 描画時の制限（JavaScript 無効化 / `mocksDir` 配下以外への要求を中断 / オフラインコンテキスト） | 描画中の他ファイル読み出し・外部へのビーコン送信 | HTML の内容による読み出し・送信 |

第 3 層は exit 2 にはならない。該当ファイルを「実体がプロジェクト外を指すため対象から除外しました」と警告したうえで、残りを撮影する。ただし `--only` でその画面を指定していた場合は空振りとなり exit 2 になる。

スキル側は第 1 層を担うが、第 2 層以降を代替しない。**どの層も単独では十分でないため、いずれも外さない。**

## 分岐の根拠

このケースが分岐するトリガーは `capture.py` の終了コード = 2（原因 = 封じ込め違反） である。case-09 と同じ exit 2 だが、原因が環境不備ではなく **入出力パスがプロジェクトルートの外を指していること** であり、案内先が venv 構築ではなく設定・パスの修正になる点が異なる。

| exit 2 の原因 | 案内 | ケース |
|-------------|------|-------|
| playwright・Chromium 未導入 | venv 構築（`design-init` / `setup_venv.sh`） | case-09 |
| 封じ込め違反（`mocksDir` / `assetsDir` がプロジェクトルート外） | 設定・パスの修正 | **本ケース** |
| `--only` の空振り | 画面 ID の確認（誤記、またはモックの削除・改名） | case-09 の終了コード表 |

本ケースの要点は、スキル側の事前検証（case-11）が万能ではないことを前提に置いている点にある。設定ファイルは第三者が書き換えうる入力であり、文字列検査を通る形で逸脱させる手段（symlink）が存在する。`capture.py` が独立に検証して exit 2 を返すことで、スキル側の検査が漏れても最終的に撮影が成立しない。

## エッジケース

| 状況 | 動作 |
|-----|------|
| `--out-dir`（`assetsDir`）側が外を指す | 同じく exit 2。メッセージは `out-dir がプロジェクトルートの外を指しています` になる。扱いは本ケースと同じ |
| `mocksDir` は内側だが個々の HTML が外を指す symlink | exit 2 にはならない。該当ファイルを警告して除外し、残りを撮影する。除外されたことを報告に含める |
| 除外された画面を `--only` で指定していた | 空振りとして exit 2（「指定された画面に対応するモックが見つかりません」）。中断する |
| `--project-root` に `.claude/design-bridge.json` が無いディレクトリを渡した | exit 2。`capture.py` は design-bridge のプロジェクトであることを要求する（`/` のような広すぎる root を与えて封じ込めを骨抜きにできないようにするため） |
| `mocksDir` が存在しない | exit 2（「モックディレクトリが見つかりません」）。中断の扱いは同じ |
| 解決に失敗する（`OSError`） | 対象から除外される。封じ込めの観点では「内側と確認できないものは撮らない」側に倒れる |

## 関連ケース

- [case-11_invalid_config_value.md](case-11_invalid_config_value.md)（同じ逸脱でも、文字列として検出できる場合はスキル側で止まり `capture.py` に到達しない）
- [case-09_screenshot_venv_missing.md](case-09_screenshot_venv_missing.md)（同じ exit 2 だが原因が環境不備で、案内先が venv 構築になる）
- [case-13_capture_partial_failure.md](case-13_capture_partial_failure.md)（同じ `capture.py` 起点の中断だが、exit 1 では続行可否をユーザーに確認する）
- [case-05_push_failure.md](case-05_push_failure.md)（同じく記録を温存するが、中断の位置が手順 5 である）
