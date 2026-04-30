# Case 07: 非対話モード（全機能デフォルト）

## 入力

以下のいずれかの呼び出し方:

- `/convert-html-full <入力MD>`
- 別スキル / コマンドからの `Skill(skill: "convert-html", args: "<入力MD>")` 呼び出し（features 引数を渡さない）

## 期待動作

1. **`AskUserQuestion` を呼び出さない**（CSS / JS 双方とも）
2. CSS は `_resolve_asset` の first-existing 解決（スキル → プラグイン共通）
3. `--js-features` オプションを **省略**
4. 結果として features.json 記載の **全機能が有効** となった HTML を出力

## 期待出力

- 全 JS 機能が結合された `<script>` タグを含む HTML
- 対話なしで処理が完了

## 分岐の根拠

`commands/convert-html-full.md`:
> CSS の選択プロンプトは出さない / JS 機能の選択プロンプトは出さない / `--js-features` オプションを **省略** することで `features.json` 記載の全機能が有効になる

`references/css-js-selection.md`:
> 別スキルからの呼び出しなど対話が難しい場合は `--js-features` を省略して全機能を導入する

## 関連ケース

- [case-04_js_exclude_interactive.md](case-04_js_exclude_interactive.md): 対話モード時の対比
