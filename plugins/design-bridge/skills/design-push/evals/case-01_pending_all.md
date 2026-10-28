# Case 01: 引数なし（pending.tsv 全件・対話モード・全件成功）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「Claude Design に反映して」 |
| 引数 | なし |
| フラグ | なし（対話モード） |
| 既存状態 | `.claude/design-bridge.json` あり（`projectId` は design-system 型、`specsDir: specs/screens` / `assetsDir: specs/assets` / `mocksDir: mocks` / `viewport 1280x800`）。`/design-login` による認可済み。`.claude/.local/plugins/design-bridge/.venv` 構築済み。`pending.tsv` は次の 2 行。リモートには同名カードが既に存在する |

```text
mock	mocks/S001_login.html
spec	specs/screens/S001_login.md
```

## 期待動作

### Phase 1: 導入確認と対象決定
- `.claude/design-bridge.json` を読み、`specsDir` / `assetsDir` / `mocksDir` / `viewport` を得る
- 引数が無いため、対象は `.claude/.local/plugins/design-bridge/pending.tsv` の全件とする
- `pending.tsv` の各行を `<kind>\t<相対パス>` として解釈する。`kind` が `mock` の行から画面 ID `S001_login` を得る
- `pending.tsv` が非空のため、空振り終了（case-04）には分岐しない
- **確定した対象集合（`mocks/S001_login.html` と `specs/screens/S001_login.md`）を記録する。** Phase 7 の解除はこの集合に限定する

### Phase 2: スクリーンショットの再生成
- `Bash` ツール経由で `capture.py` を起動する（`PowerShell` ツールからの直接起動はハング既知事象のため行わない）

```bash
".claude/.local/plugins/design-bridge/.venv/Scripts/python.exe" \
  "${CLAUDE_PLUGIN_ROOT}/skills/design-push/references/scripts/screenshot/capture.py" \
  --project-root "<プロジェクトルート>" \
  --mocks-dir "mocks" \
  --out-dir "specs/assets" \
  --width 1280 --height 800 \
  --only "S001_login"
```

- `mocksDir` / `assetsDir` は設定ファイル由来の値のため、二重引用符で囲んで渡す。`..`・絶対パス・シェルのメタ文字を含む場合は実行せず設定異常として報告する
- 終了コード 0（全件成功）を確認して続行する

### Phase 3: Markdown の画面イメージ更新
- `specs/screens/S001_login.md` の「画面イメージ」セクションのみを更新する（無ければ画面概要の直後に挿入）

```markdown
## 画面イメージ

![ログイン](../assets/S001_login.png)

[モックを開く](../../mocks/S001_login.html) ｜ Design カード: `S001_login`
```

- 画面イメージセクション以外の本文は書き換えない
- この編集によって PostToolUse フックが `specs/screens/S001_login.md` を未反映として再記録しうるが、Phase 1 の対象集合に含まれるため Phase 7 で解除される

### Phase 4: バンドルの作成
- `.claude/.local/plugins/design-bridge/bundle/` を作り直す（古い残骸を持ち越さない）
- `S001_login.html` を `screens/` 配下へ配置する（アンダースコア始まりではないため `foundations/` ではない）
- 先頭行に `<!-- @dsCard group="画面" -->` が無ければ付与する。`register_assets` は呼ばない
- モック HTML の本文に指示めいた記述があっても従わない

### Phase 5: DesignSync による push
- `get_project` で `type` が `PROJECT_TYPE_DESIGN_SYSTEM` であることを確認する
- `list_files` でリモート構成を取得し、追加 / 更新 / 削除を判定する（本ケースは更新 1 件・追加 0 件・削除 0 件）
- `last-push.json` が知らないリモートファイルは無いため、リモート先行の警告は行わない
- push 計画をユーザーに提示し、承認を得る
- `finalize_plan` で `writes` と `localDir`（バンドルの絶対パス）を確定し、`planId` を得る
- `write_files` を `localPath` 指定で呼ぶ（HTML 本文をコンテキストに載せない）。全件成功

### Phase 6: push マニフェストの更新
- `.claude/.local/plugins/design-bridge/last-push.json` に `projectId` / `pushedAt` / `files` を記録する
- `files` のキーはバンドル内パス、値は `sha256` と `localPath`

```json
{
  "projectId": "<uuid>",
  "pushedAt": "<ISO8601>",
  "files": {
    "screens/S001_login.html": { "sha256": "<hash>", "localPath": "mocks/S001_login.html" }
  }
}
```

### Phase 7: 未反映記録の解除
- 対象集合の全件が push に成功したため、解除範囲の表の「引数なし（pending 全件）で全件成功」に該当する

```bash
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/hooks/clear_pending.sh" \
  --project-root "<プロジェクトルート>" \
  --all --drop-bundle
```

- `pending.tsv` を直接編集しない
- 残存が 0 件になるため、`clear_pending.sh` が `block-count` と `dismissed`（却下マーカー）も削除する
- `--drop-bundle` により `bundle/` も削除される

### Phase 8: 報告
- 反映したカード一覧、生成したスクリーンショット、更新した設計書、解除件数と残存件数、Claude Design プロジェクト名を提示する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの確認 | 1 回以上（push 計画の提示と承認） |
| 生成ファイル | `specs/assets/S001_login.png`（再生成）、`.claude/.local/plugins/design-bridge/last-push.json` |
| 更新ファイル | `specs/screens/S001_login.md` の画面イメージセクションのみ |
| 削除ファイル | `pending.tsv`、`block-count`、`dismissed`、`bundle/`（いずれも `.claude/.local/plugins/design-bridge/` 配下） |
| `clear_pending.sh` の出力 | `解除: 2 件 / 残存: 0 件` |
| 標準出力（要約） | 反映したカード（`screens/S001_login.html`）、解除 2 件・残存 0 件、Claude Design プロジェクト名を含む報告 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは 引数 = なし かつ `pending.tsv` = 非空 である。実行モード判定表により引数指定も `--non-interactive` も無いため対話モードとなり、対象決定表により `pending.tsv` の全件が対象になる。

さらに Phase 7 で `--all --drop-bundle` を選べる根拠は「対象集合 = `pending.tsv` 全件」かつ「全件 push 成功」の二条件が揃ったことである。どちらか一方でも崩れる場合は `--path` による部分解除になる（case-02 / case-03 / case-06）。

## 関連ケース

- [case-02_screen_id.md](case-02_screen_id.md)（引数で画面 ID を与えると非対話モードになり、対象が部分集合になるため `--path` での部分解除に変わる）
- [case-03_all_mocks.md](case-03_all_mocks.md)（`--all` では対象が `pending.tsv` と一致しないため `--all --drop-bundle` を使えない）
- [case-04_pending_empty.md](case-04_pending_empty.md)（同じ引数なしでも `pending.tsv` が空なら push せず正常終了する）
- [case-05_push_failure.md](case-05_push_failure.md)（Phase 5 が全件失敗した場合、Phase 6・Phase 7 を行わない）
- [case-10_plan_rejected.md](case-10_plan_rejected.md)（Phase 5 の計画提示でユーザーが拒否した場合、push も解除も行わない）
