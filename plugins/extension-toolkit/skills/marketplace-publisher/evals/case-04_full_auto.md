# Case 04: フルオートモード（ADR-020 委譲 + ADR-019 README 同期）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`extension-toolkit` プラグインをフルオートで公開" |
| 引数 | `extension-toolkit --full-auto` |
| フラグ | `--full-auto` |
| 既存状態 | プラグイン実体あり、未登録、`feature/extension-toolkit` ブランチ |

## 期待動作

### Phase 1: 現状確認

`.claude-plugin/marketplace.json` を Read。`extension-toolkit` が未登録を確認。

### Phase 2: プラグイン実体検証

`plugins/extension-toolkit/.claude-plugin/plugin.json` 存在 + name 一致を確認。
**シークレット混入スキャン**（[`../references/secret-scan.md`](../references/secret-scan.md)）を実施。検出時は fail-closed で公開フローを中断（`--full-auto` でも例外なく中断）。

### Phase 3: 重複チェック

`marketplace.json` の既存 `plugins[]` を比較。重複なし → 続行。

### Phase 4: marketplace-toolkit への委譲（ADR-020 準拠）

```text
Skill(skill: "marketplace-toolkit",
      args: "--add-plugin extension-toolkit --description '<plugin.json description>' --source ./plugins/extension-toolkit")
```

`marketplace-toolkit` が `plugins[]` 追加 + リポジトリルート `README.md` 同期を行う（ADR-019）。

### Phase 5: 同期確認 + プラグイン名バリデーション

| 確認項目 | 動作 |
|---------|------|
| `marketplace.json` 編集差分 | 含まれることを確認 |
| リポジトリルート `README.md` 編集差分 | 含まれることを確認、不整合時は `--sync-readme` 再呼び出し |
| `plugin-name` 正規表現 `^[a-z][a-z0-9-]*$` | コマンド注入対策、不一致時はエラー終了 |

### Phase 6: ブランチ確認（保護ブランチ阻止）

`git branch --show-current` で `feature/extension-toolkit` を確認。
保護パターン（`main` / `master` / 設定で追加されたパターン）に合致しないため進行。
合致時は fail-closed で中断（[case-06_full_auto_on_main_blocked.md](case-06_full_auto_on_main_blocked.md) 参照）。

### Phase 7: リモート種別判定

`git remote -v` で URL を取得、リモート種別を判定（GitHub / TFS / その他）。

### Phase 8: git add + commit + push（README.md を必ず含める）

```bash
git add plugins/extension-toolkit .claude-plugin/marketplace.json README.md
git commit -m "Add plugin: extension-toolkit"
git push origin feature/extension-toolkit
```

`README.md` はリポジトリルートのマーケットプレイス README を指す（ADR-019 同期義務）。コミット前に再度同期確認を実施し、不整合時は push しない（fail-closed）。

### Phase 9: PR 作成

リモート種別に応じて `gh pr create` または `tfs_create_pull_request` を呼び出す。

### Phase 10: PR URL 提示

```text
PR 作成完了: {PR URL}

マージ後の利用者向けインストール手順:
  /plugin marketplace add {marketplace-url}
  /plugin install extension-toolkit@dmajima-claude-plugins
```

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `.claude-plugin/marketplace.json` + リポジトリルート `README.md`（ADR-019 同期） |
| 標準出力 | フルオート進行ログ + PR URL |
| 終了状態 | 完了（PR 作成済み） |

## 分岐の根拠

`--full-auto` フラグ + フィーチャーブランチで作業中 + シークレット未検出。
すべての破壊的操作前にバリデーションが入る fail-closed 設計。

## 関連ケース

- `case-01_new_register_handoff.md`（ハンドオフモード）
- `case-06_full_auto_on_main_blocked.md`（保護ブランチ阻止）
- `case-07_secret_scan_blocked.md`（シークレット検出時の fail-closed）
