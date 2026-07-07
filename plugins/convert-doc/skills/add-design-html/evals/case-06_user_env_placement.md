# Case 06: 利用者モード配置

## 入力

- convert-doc をプラグインとして導入した一般リポジトリ（convert-doc のソースを含まない）内で実行
- 検証 PASS 済みデザイン `warm-paper.css`

## 期待動作

1. カレントリポジトリに `plugins/convert-doc/.claude-plugin/plugin.json` が **存在しない** ことから **利用者モード** と判定する
2. 配置先 `<repo_root>/.claude/.local/plugins/convert-doc/designs/css/warm-paper.css` を提示する
   （リポジトリ外での作業なら `~/.claude/.local/plugins/convert-doc/designs/css/`）
3. **`${CLAUDE_PLUGIN_ROOT}`（プラグインキャッシュ）には書き込まない**
4. 承認後に配置する

## 期待出力

- ローカルデザインディレクトリ配下のデザイン CSS（プラグイン更新で消えない位置）

## 分岐の根拠

`references/design-locations.md` 節 3〜4、`SKILL.md`「重要な制約」:
> `${CLAUDE_PLUGIN_ROOT}` 配下（プラグインキャッシュ）へ書き込まない

## 関連ケース

- [case-05_dev_repo_placement.md](case-05_dev_repo_placement.md): 開発モード
