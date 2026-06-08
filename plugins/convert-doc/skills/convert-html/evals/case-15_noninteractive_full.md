# Case 15: 非対話モード（/convert-html-full 指定）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "/convert-html-full input.md output.html" |
| モード | 非対話 |

## 期待動作

- convert-html スキルが非対話モードで起動する
- CSS 選択 UI を表示しない
- JS 機能の除外選択 UI を表示しない
- `--js-features` オプションを省略し全機能有効で処理する
- CSS は `_resolve_asset` の first-existing 解決を使用する

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | 全機能有効の自己完結型 HTML ファイル（指定パスに出力） |
| 対話プロンプト | なし（CSS / JS 双方とも選択 UI を出さない） |

## 分岐の根拠

SKILL.md の実行モード判定表で「`/convert-html-full` → 非対話モード」に該当。CSS / JS の対話プロンプトを出さず全機能有効で処理する分岐。

## 関連ケース

- [case-07_non_interactive_full_features.md](case-07_non_interactive_full_features.md): 非対話モードの詳細（別スキルからの呼び出し含む）
- [case-12_trigger_md_to_html.md](case-12_trigger_md_to_html.md): 対話モードとの対比
