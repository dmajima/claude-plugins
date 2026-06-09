# Case 05: プラグイン削除（明示確認、ADR-020 委譲）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`legacy-plugin` をマーケットプレイスから削除" |
| 引数 | `legacy-plugin --remove` |
| フラグ | `--remove` |
| 既存状態 | `legacy-plugin` が marketplace.json に登録済 |

## 期待動作

### Phase 1: 現状確認

該当エントリを検出。

### Phase 2: marketplace-toolkit への委譲（ADR-020 準拠）

削除操作（`marketplace.json` エントリ削除 + マーケットプレイス README 同期 + 必要に応じてファイル本体削除）は本スキルでは行わない。
Skill ツール経由で `marketplace-toolkit` を呼び出し:

```text
Skill(skill: "marketplace-toolkit",
      args: "--remove-plugin legacy-plugin")
```

`marketplace-toolkit` 側で実行されること（[`../../marketplace-toolkit/evals/case-03_remove_plugin.md`](../../marketplace-toolkit/evals/case-03_remove_plugin.md) 参照）:

- ユーザに **明示的確認**（`AskUserQuestion`）で以下を選択させる
  1. `marketplace.json` + README + ファイル本体削除
  2. `marketplace.json` + README のみ削除（ファイル保持）
  3. キャンセル
- 選択 1 はファイル本体削除前に **二重確認**
- 選択結果に応じてエントリ削除 + リポジトリルート `README.md` のテーブル行削除

戻り値（成功/失敗、どの選択で実行されたか）を受け取る。キャンセル時は本スキルでの後続処理を中断。

### Phase 3: 同期確認 + 公開モード確認

| 確認項目 | 動作 |
|---------|------|
| `marketplace.json` から `legacy-plugin` エントリが削除されている | 必須 |
| リポジトリルート `README.md` のテーブルから該当行が削除されている | 必須 |
| ファイル本体削除有無 | `marketplace-toolkit` の戻り値で確認 |

ユーザに「ハンドオフ / フルオート」を選択させる（`AskUserQuestion`）。

### Phase 4: コミット範囲

```bash
git add .claude-plugin/marketplace.json README.md
# ファイル本体削除選択時は plugins/legacy-plugin/ も含む
git commit -m "Remove plugin: legacy-plugin"
```

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `.claude-plugin/marketplace.json`（エントリ削除）+ リポジトリルート `README.md`（テーブル行削除）+ 任意で `plugins/legacy-plugin/` 削除 |
| 標準出力 | 削除確認結果 + 公開ハンドオフ or フルオート |
| 終了状態 | 確認結果により異なる |

## 分岐の根拠

`--remove` フラグ + 既存エントリあり。
削除操作は ADR-020 に従い `marketplace-toolkit` に委譲し、明示確認・README 同期もそちらで完結する。

## 関連ケース

- `case-04_full_auto.md`（フルオート公開）
- `../../marketplace-toolkit/evals/case-03_remove_plugin.md`（委譲先の詳細フロー）
