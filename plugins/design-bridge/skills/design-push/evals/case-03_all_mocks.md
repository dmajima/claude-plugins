# Case 03: `--all` 指定（全モック対象・リモート余剰ファイルの削除確認）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「全部まとめて Claude Design に反映して」 |
| 引数 | `--all` |
| フラグ | `--all`（引数で対象を指定しているため非対話モード） |
| 既存状態 | `.claude/design-bridge.json` あり（design-system 型）。認可済み・venv 構築済み。`mocksDir` に `_tokens.html` `_layout.html` `S001_login.html` `S002_home.html` の 4 件。`specsDir` に `S001_login.md` `S002_home.md` `S003_report.md`（`S003_report` にはモックがまだ無い）。リモートには加えて `screens/S900_old.html` が存在し、ローカルに対応ファイルが無い。`last-push.json` に `screens/S900_old.html` の記録は無い。`pending.tsv` は次の 3 行 |

```text
mock	mocks/S001_login.html
spec	specs/screens/S001_login.md
spec	specs/screens/S003_report.md
```

## 期待動作

### Phase 1: 導入確認と対象決定
- `--all` が指定されているため、対象決定表により `mocksDir` 配下の全モック 4 件を対象とする
- `pending.tsv` の内容は対象決定に使わない（空であっても `--all` では空振り終了しない）
- **対象集合はモック 4 件と、Phase 3 で画面イメージを更新する設計書のみ。** `specs/screens/S003_report.md` は対応モックが無く push 対象にもならないため、対象集合に含めない

### Phase 2: スクリーンショットの再生成
- `capture.py` を `--only` なしで `Bash` ツール経由から起動し、`--skip-partials` を付けて部品（`_tokens.html` / `_layout.html`）を撮影対象から外す

```bash
".claude/.local/plugins/design-bridge/.venv/Scripts/python.exe" \
  "${CLAUDE_PLUGIN_ROOT}/skills/design-push/references/scripts/screenshot/capture.py" \
  --project-root "<プロジェクトルート>" \
  --mocks-dir "mocks" \
  --out-dir "specs/assets" \
  --width 1280 --height 800 \
  --skip-partials
```

- `S001_login.png` と `S002_home.png` が生成される。終了コード 0 を確認して続行する
- `--skip-partials` はスクリーンショットの対象だけを絞るものであり、Phase 4 のバンドル対象は絞らない

### Phase 3: Markdown の画面イメージ更新
- モックとスクリーンショットが揃っている `specs/screens/S001_login.md` と `specs/screens/S002_home.md` の画面イメージセクションを更新する
- `specs/screens/S003_report.md` は対応モックが無いため更新しない（存在しない画像を参照させない）

### Phase 4: バンドルの作成
- バンドルを作り直す
- アンダースコア始まりの `_tokens.html` `_layout.html` を `foundations/` へ、それ以外を `screens/` へ配置する

```text
bundle/
├─ foundations/
│  ├─ _tokens.html
│  └─ _layout.html
└─ screens/
   ├─ S001_login.html
   └─ S002_home.html
```

- 各 HTML の先頭行に `@dsCard` マーカーが無ければ付与する（`foundations/` 側は `group="Foundations"`、`screens/` 側は `group="画面"`）

### Phase 5: DesignSync による push と削除確認
- `get_project` で `type` が `PROJECT_TYPE_DESIGN_SYSTEM` であることを確認する
- `list_files` の結果とバンドルを突き合わせ、追加 / 更新 / 削除を判定する
- リモートのみに存在する `screens/S900_old.html` を **削除候補** として検出する
- 削除候補はローカルで意図的に消したものか、Claude Design 側で別経路に追加されたものかを区別できないため、**削除してよいかを必ずユーザーに確認する**
- 本ケースではユーザーが削除を承認しなかったものとし、`deletes` から除外して `writes` のみで計画を確定する
- `screens/S900_old.html` は `last-push.json` に記録が無いリモートファイルであるため、上書き前に `design-status` または `design-pull` での確認をユーザーへ提案する
- `finalize_plan`（`writes` / 空の `deletes` / `localDir`）→ `write_files`（`localPath` 指定）の順で実行する。4 件すべて成功
- 承認されていれば同じ `planId` で `delete_files` を呼ぶが、本ケースでは呼ばない
- 対象が 256 ファイルを超える場合は同一 `planId` で複数回に分割する（本ケースは 4 件のため分割なし）

### Phase 6: push マニフェストの更新
- push に成功した 4 件を `last-push.json` の `files` に記録する（`foundations/_tokens.html` `foundations/_layout.html` `screens/S001_login.html` `screens/S002_home.html`）

### Phase 7: 未反映記録の解除
- 解除範囲の表の「`--all` で成功」に該当するため、**push したモックと Phase 3 で更新した設計書のみ** を `--path` で列挙する

```bash
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/hooks/clear_pending.sh" \
  --project-root "<プロジェクトルート>" \
  --path "mocks/_tokens.html" \
  --path "mocks/_layout.html" \
  --path "mocks/S001_login.html" \
  --path "mocks/S002_home.html" \
  --path "specs/screens/S001_login.md" \
  --path "specs/screens/S002_home.md"
```

- **`--all --drop-bundle` を使わない。** 使うと、対象外の `specs/screens/S003_report.md` の記録まで消える
- `pending.tsv` に記録が無いパスを `--path` に含めても害は無い（該当行が無いだけ）。逆に対象集合に無いパスを含めてはならない
- `specs/screens/S003_report.md` の 1 行が残るため、`pending.tsv` は削除されず `block-count` も削除されない

### Phase 8: 報告
- 反映したカード 4 件、削除候補の扱い（見送り）、リモート先行の疑いと `design-status` / `design-pull` での確認提案を提示する
- 未反映のまま残った `specs/screens/S003_report.md` を明示し、モック未作成のため `design-mock` でのモック生成が次の手であることを案内する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの確認 | 2 回以上（push 計画の提示、削除候補 `screens/S900_old.html` の可否確認） |
| 生成ファイル | `specs/assets/S001_login.png`・`specs/assets/S002_home.png`、バンドル内 `foundations/` 2 件 + `screens/` 2 件、`last-push.json` |
| 更新ファイル | `specs/screens/S001_login.md` と `specs/screens/S002_home.md` の画面イメージセクションのみ |
| 削除しないもの | リモートの `screens/S900_old.html`（ユーザーが承認しなかったため `deletes` に含めない） |
| 残存ファイル | `pending.tsv`（`spec` / `specs/screens/S003_report.md` の 1 行が残る） |
| `clear_pending.sh` の出力 | `解除: 2 件 / 残存: 1 件` |
| 標準出力（要約） | 反映カード 4 件、削除候補の扱い、`design-status` / `design-pull` での確認提案、残存 1 件の明示 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは 引数 = `--all` である。対象決定表により、対象が `pending.tsv` ではなく `mocksDir` 配下の全モックになる。

ここで解除方法が `--all --drop-bundle` にならないのは、**対象集合と `pending.tsv` の内容が一致しない**ためである。`--all` はモックを起点に対象を決めるため、モックを持たない設計書の未反映記録（`specs/screens/S003_report.md`）が対象外として残る。

第二のトリガーは `list_files` の結果に **バンドルへ存在しないリモートファイルが含まれること** であり、これが削除確認フローとリモート先行の提案を発火させる。

## 関連ケース

- [case-01_pending_all.md](case-01_pending_all.md)（対象が `pending.tsv` 全件に限られるため `mocksDir` の未変更モックは対象外になり、解除は `--all --drop-bundle` になる）
- [case-02_screen_id.md](case-02_screen_id.md)（同じ非対話モードだが対象が 1 画面に限定される）
- [case-04_pending_empty.md](case-04_pending_empty.md)（`pending.tsv` が空でも `--all` なら空振り終了しない点が対照的）
- [case-10_plan_rejected.md](case-10_plan_rejected.md)（本ケースは削除候補のみを拒否して `writes` を続行するのに対し、計画全体を拒否した場合は何も push せず中断する）
