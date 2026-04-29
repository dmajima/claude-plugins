# Case 04: フルオートモード

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`extension-toolkit` プラグインをフルオートで公開" |
| 引数 | `extension-toolkit --full-auto` |
| フラグ | `--full-auto` |
| 既存状態 | プラグイン実体あり、未登録、`feature/extension-toolkit` ブランチ |

## 期待動作

### Phase 1〜4: case-01 と同じ

現状確認 → 実体検証 → 重複チェック → marketplace.json 更新。

### Phase 5: ブランチ確認

`git branch --show-current` で `feature/extension-toolkit` を確認。`main`/`master` でないため進行。

### Phase 6: リモート種別判定

`git remote -v` で URL を取得、リモート種別を判定（GitHub / TFS / その他）。

### Phase 7: git add + commit + push

```bash
git add plugins/extension-toolkit .claude-plugin/marketplace.json
git commit -m "Add plugin: extension-toolkit"
git push origin feature/extension-toolkit
```

### Phase 8: PR 作成

リモート種別に応じて `gh pr create` または `tfs_create_pull_request` を呼び出す。

### Phase 9: PR URL 提示

```text
PR 作成完了: {PR URL}

マージ後の利用者向けインストール手順:
  /plugin marketplace add {marketplace-url}
  /plugin install extension-toolkit@dmajima-claude-plugins
```

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `.claude-plugin/marketplace.json` |
| 標準出力 | フルオート進行ログ + PR URL |
| 終了状態 | 完了（PR 作成済み） |

## 分岐の根拠

`--full-auto` フラグ + フィーチャーブランチで作業中。
