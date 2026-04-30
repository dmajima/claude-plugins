# Case 02: 既存プラグイン更新（description 変更、ADR-020 委譲）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`extension-toolkit` の description を更新" |
| 引数 | `extension-toolkit --description "新しい説明"` |
| フラグ | なし |
| 既存状態 | `extension-toolkit` が marketplace.json に登録済 |

## 期待動作

### Phase 1: 現状確認

既存エントリを検出。

### Phase 2: 整合性確認

`plugin.json` の `description` と引数 `--description` が一致するか確認。不一致時はユーザに確認（`AskUserQuestion`）。
シークレット混入スキャンも合わせて実施（[`../references/secret-scan.md`](../references/secret-scan.md)）。

### Phase 3: marketplace-toolkit への委譲（ADR-020 準拠）

`marketplace.json` の編集と マーケットプレイス README 同期は本スキルでは行わない。
Skill ツール経由で `marketplace-toolkit` を呼び出し:

```text
Skill(skill: "marketplace-toolkit",
      args: "--update-plugin extension-toolkit --description '新しい説明'")
```

`marketplace-toolkit` 側で実行されること:

- 該当エントリの `description` を更新（他フィールドは維持）
- リポジトリルート `README.md` のプラグイン一覧テーブルを再生成（ADR-019）

### Phase 4: 同期確認

| 確認項目 | 動作 |
|---------|------|
| `marketplace.json` の description 列差分 | 反映されていることを確認 |
| リポジトリルート `README.md` の説明列差分 | 同上、テーブル行が更新されていることを確認 |

### Phase 5: 公開モード確認 + 実行

ユーザに「ハンドオフ / フルオート」を選択させる。
推奨 git add コマンド:

```bash
git add .claude-plugin/marketplace.json README.md
git commit -m "Update plugin: extension-toolkit (description)"
```

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `.claude-plugin/marketplace.json` + リポジトリルート `README.md`（ADR-019 同期） |
| 標準出力 | ハンドオフ or フルオート結果 |
| 終了状態 | 完了 |

## 分岐の根拠

既存エントリあり + 更新指示。`marketplace.json` 編集と README 同期は ADR-020 に従い `marketplace-toolkit` に委譲する。

## 関連ケース

- `case-01_new_register_handoff.md`（新規登録）
- `case-05_removal.md`（削除）
