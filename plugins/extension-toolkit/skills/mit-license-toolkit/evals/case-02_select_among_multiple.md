# Case 02: license-info.json に複数エントリ存在し AskUserQuestion で選択

## シナリオ

複数のクライアントワークを 1 つのリポジトリで管理しており、`license-info.json` に 2 件のエントリが登録されている。

## 入力

ユーザ:
> `acme-toolkit` プラグインに MIT ライセンスを追加

事前状態:
- `license-info.json` に 2 件:
  ```json
  {
    "version": 1,
    "licenses": [
      { "id": "personal", "type": "MIT", "copyright_year": "2026", "copyright_holder": "Taro Yamada", "author": "Taro Yamada", "label": "個人プロジェクト用" },
      { "id": "acme", "type": "MIT", "copyright_year": "2026", "copyright_holder": "Acme Corporation", "author": "Acme Corporation", "label": "Acme 社プロジェクト用" }
    ]
  }
  ```
- `plugins/acme-toolkit/` 配下に LICENSE / `plugin.json.license` なし

## 期待動作

1. `license-info.json` を解決、`licenses[]` 2 件を検出
2. `AskUserQuestion` で利用エントリを選択（選択肢ラベルは `label`、description に holder + year）
   - 選択肢: `個人プロジェクト用` / `Acme 社プロジェクト用` / `新規追加`
3. ユーザが「Acme 社プロジェクト用」を選択
4. `plugins/acme-toolkit/LICENSE` を生成（`Copyright (c) 2026 Acme Corporation`）
5. `plugin.json.license = "MIT"` 設定
6. 検証 PASS、`readme-toolkit` / `marketplace-publish` への接続案内

## 失敗条件

- 自動適用してしまう（複数あるときは選択 UI 必須）
- テキスト対話で「1 / 2」のような番号入力で選択させる（AskUserQuestion 必須）
- 選択肢に「キャンセル」が含まれない（重要選択は中止可能であるべき）
