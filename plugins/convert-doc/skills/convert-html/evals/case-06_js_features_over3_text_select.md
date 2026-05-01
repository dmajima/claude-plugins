# Case 06: features.json 3 機能以上 → テキストベース選択

## 入力

- 入力 MD: 任意
- features.json に 3 機能以上が登録されている

## 期待動作

1. `AskUserQuestion` の options 上限（4 件、「全て不要」を含む）に収まらないため **テキストベース選択** に切り替え
2. 機能名を番号付きリストで列挙し、除外したい機能の番号またはカンマ区切り名をユーザーに返答してもらう
3. 入力に応じて `--js-features` を解決

## 期待出力

選択された機能のみ埋め込まれた HTML

## 分岐の根拠

`references/css-js-selection.md`「制約」節（JS 機能）:
> features.json の機能が 3 件以上になる場合はテキストベースの選択に切り替える

## 関連ケース

- [case-04_js_exclude_interactive.md](case-04_js_exclude_interactive.md): 1-2 機能（AskUserQuestion）
