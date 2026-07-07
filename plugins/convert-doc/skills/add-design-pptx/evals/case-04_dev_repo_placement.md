# Case 04: 開発モード配置

## 入力

- convert-doc のソースリポジトリ（`plugins/convert-doc/.claude-plugin/plugin.json` が存在するリポジトリ）内で実行
- 検証 PASS 済みテーマ `ocean-blue.json`

## 期待動作

1. カレントリポジトリに `plugins/convert-doc/.claude-plugin/plugin.json` が存在することを検出し **開発モード** と判定する
2. 配置先 `<repo_root>/plugins/convert-doc/assets/pptx-themes/ocean-blue.json` を提示する
3. 承認後に配置する（`assets/pptx-themes/` が無ければ作成）

## 期待出力

- リポジトリの `plugins/convert-doc/assets/pptx-themes/ocean-blue.json`（配布物として git 管理対象になる位置）

## 分岐の根拠

`references/design-locations.md` 節 4:
> 開発モード: カレントリポジトリ内に `plugins/convert-doc/.claude-plugin/plugin.json` が存在する → `<repo_root>/plugins/convert-doc/assets/...`

## 関連ケース

- [case-05_user_env_placement.md](case-05_user_env_placement.md): 利用者モード
