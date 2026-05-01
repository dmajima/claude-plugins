# Case 01: 新規登録（ハンドオフ、ADR-020 委譲モデル）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`extension-toolkit` プラグインを公開" |
| 引数 | `extension-toolkit` |
| フラグ | なし |
| 既存状態 | プラグイン実体あり、marketplace.json に未登録 |

## 期待動作

### Phase 1: 現状確認

`.claude-plugin/marketplace.json` を Read。`extension-toolkit` が未登録を確認。

### Phase 2: プラグイン実体検証

`plugins/extension-toolkit/.claude-plugin/plugin.json` 存在 + name 一致を確認。
**シークレット混入スキャン**（[`../references/secret-scan.md`](../references/secret-scan.md)）を実施し、検出時は fail-closed で公開フローを中断。

### Phase 3: 重複チェック

`marketplace.json` の既存 `plugins[]` を比較。重複なし → 新規登録続行。
重複検出時は `marketplace-toolkit` の更新モード or `plugin-toolkit` の追加シナリオへ案内（[references/duplication-check.md](../references/duplication-check.md) 参照）。

### Phase 4: marketplace-toolkit への委譲（ADR-020 準拠）

`marketplace.json` の編集と マーケットプレイス README 同期は本スキルでは行わない。
Skill ツール経由で `marketplace-toolkit` を呼び出し:

```text
Skill(skill: "marketplace-toolkit",
      args: "--add-plugin extension-toolkit --description '<extension-toolkit の plugin.json description>' --source ./plugins/extension-toolkit")
```

`marketplace-toolkit` 側で実行されること:

- `plugins[]` に新エントリ追加（アルファベット順維持）
- リポジトリルート `README.md` のプラグイン一覧テーブルを再生成（ADR-019）
- JSON 整合性 + README 同期の検証

戻り値（成功/失敗）を受け取り、失敗時は本スキルでの後続処理を中断。

### Phase 5: 同期確認（ADR-019）

| 確認項目 | 動作 |
|---------|------|
| `marketplace.json` 編集差分 | `marketplace-toolkit` 実行結果に含まれることを確認 |
| リポジトリルート `README.md` 編集差分 | 同上、テーブル行追加が含まれることを確認 |
| 不整合検出時 | `marketplace-toolkit --sync-readme` を再呼び出し |

### Phase 6: 公開モード確認

ユーザに「ハンドオフ / フルオート」を選択させる（`AskUserQuestion`）。「ハンドオフ」選択時は次へ。

### Phase 7: ハンドオフ提示

変更ファイル一覧（**`marketplace.json` + リポジトリルート `README.md` の両方を含む**）+ 差分 + 推奨コミットメッセージ + 次のコマンド + PR 作成 URL を提示。

推奨 git add コマンド:

```bash
git add plugins/extension-toolkit .claude-plugin/marketplace.json README.md
git commit -m "Add plugin: extension-toolkit"
```

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `.claude-plugin/marketplace.json` + リポジトリルート `README.md`（ADR-019 同期） |
| 標準出力 | ハンドオフフォーマット（git コマンド + PR 作成 URL） |
| 終了状態 | 完了（コミット以降はユーザ実施） |

## 分岐の根拠

重複なし + ハンドオフモード選択 + シークレット未検出。
`marketplace.json` 編集と README 同期は ADR-020 に従い `marketplace-toolkit` に委譲する。

## 関連ケース

- `case-02_existing_update.md`（既存プラグイン更新）
- `case-04_full_auto.md`（フルオート公開）
- `case-07_secret_scan_blocked.md`（シークレット検出時の fail-closed）
