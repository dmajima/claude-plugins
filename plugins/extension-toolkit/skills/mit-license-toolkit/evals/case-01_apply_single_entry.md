# Case 01: license-info.json に 1 件のみ存在し自動適用

## シナリオ

`dev-toolkit` プラグインに MIT ライセンスを追加するシーン。`license-info.json` には 1 件のみエントリが登録されている。

## 入力

ユーザ:
> `dev-toolkit` プラグインに LICENSE を追加して

事前状態:
- `<repo_root>/.claude/.local/plugins/extension-toolkit/license-info.json` が存在
- 内容:
  ```json
  {
    "version": 1,
    "licenses": [
      {
        "id": "personal",
        "type": "MIT",
        "copyright_year": "2026",
        "copyright_holder": "Taro Yamada",
        "author": "Taro Yamada",
        "label": "個人プロジェクト用"
      }
    ]
  }
  ```
- `plugins/dev-toolkit/.claude-plugin/plugin.json` に `license` フィールドなし
- `plugins/dev-toolkit/LICENSE` 不在

## 期待動作

1. `license-info.json` を解決し、`licenses[]` が 1 件であることを検出
2. **AskUserQuestion を使わず自動適用**（適用したエントリの label `個人プロジェクト用` を通知）
3. `plugins/dev-toolkit/LICENSE` を生成（MIT 標準文 + `Copyright (c) 2026 Taro Yamada`）
4. `plugins/dev-toolkit/.claude-plugin/plugin.json` に `"license": "MIT"` を追加
5. 検証: `verify_license.py dev-toolkit` が PASS
6. 引き渡し: `readme-toolkit`（README にライセンスセクション追加） / `marketplace-publish` への接続案内

## 期待出力（要約）

```
個人プロジェクト用 (Taro Yamada / 2026) を自動適用しました。
- plugins/dev-toolkit/LICENSE を生成
- plugins/dev-toolkit/.claude-plugin/plugin.json の license="MIT" を設定
次のステップ: readme-toolkit で「ライセンス」セクションを追加してください。
```

## 失敗条件

- AskUserQuestion を呼んでしまう（1 件のみのとき選択 UI は出さない）
- LICENSE 本文に `{year}` や `{copyright_holder}` のプレースホルダが残る
- `plugin.json.license` が `"MIT"` 以外、または不在
