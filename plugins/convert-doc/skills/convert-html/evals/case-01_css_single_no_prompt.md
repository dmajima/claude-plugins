# Case 01: CSS が合算 1 ファイル → 選択プロンプトなし

## 入力

- 入力 MD: 任意（最小限の `# タイトル` のみで可）
- `${CLAUDE_SKILL_DIR}/assets/css/`: 空、または `template.css` のみ
- `${CLAUDE_PLUGIN_ROOT}/assets/css/`: `template.css` のみ
- 合算後: 同名ファイルがある場合スキル側を優先 → 結果として 1 ファイル

## 期待動作

1. CSS 選択用の `AskUserQuestion` を **呼び出さない**
2. 唯一存在する CSS ファイルを `--css-template` に解決して `convert.py` を実行
3. 出力 HTML には当該 CSS が `<style>` タグでインラインに埋め込まれる

## 期待出力

- 出力 HTML 1 ファイル
- スキル側に `template.css` がある場合: `${CLAUDE_SKILL_DIR}/assets/css/template.css` の内容
- それ以外: `${CLAUDE_PLUGIN_ROOT}/assets/css/template.css` の内容

## 分岐の根拠

`SKILL.md`「実行モード判定」および `references/css-js-selection.md`「制約」節:
> `${CLAUDE_SKILL_DIR}/assets/css/` と `${CLAUDE_PLUGIN_ROOT}/assets/css/` の合算で `.css` ファイルが 1 つだけの場合は選択肢を提示せずにそのまま使用する

## 関連ケース

- [case-02_css_multi_interactive.md](case-02_css_multi_interactive.md): 2-3 ファイル時の対話選択
- [case-03_css_over4_text_select.md](case-03_css_over4_text_select.md): 4 ファイル以上のテキスト選択
