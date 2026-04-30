# Case 02: CSS が合算 2-3 ファイル → AskUserQuestion で選択

## 入力

- 入力 MD: 任意
- `${CLAUDE_PLUGIN_ROOT}/assets/css/template.css`（プラグイン共通）
- `${CLAUDE_SKILL_DIR}/assets/css/dark-theme.css`（スキル固有・プラグイン共通とは別名）
- 合算: 2 ファイル

## 期待動作

1. `AskUserQuestion` を以下の引数で呼び出す:
   - `question`: `"適用するCSSを選択してください。"`
   - `header`: `"CSS"`
   - `multiSelect`: `false`
   - `options` 配列に `template.css`（プラグイン共通）と `dark-theme.css`（スキル）の 2 件を `{ label, description }` 形式で列挙
2. ユーザー選択結果（ファイル名）を絶対パスに解決
3. `--css-template "<絶対パス>"` を `convert.py` に渡す
4. **回答受け取り後、再確認なしでそのまま処理を続行する**

## 期待出力

選択されたファイルの CSS 内容が `<style>` タグでインラインに埋め込まれた HTML

## 分岐の根拠

`references/css-js-selection.md`「呼び出し方針」節:
> CSS が 2 つ以上存在する場合は `AskUserQuestion` ツールで選択させる

## 関連ケース

- [case-01_css_single_no_prompt.md](case-01_css_single_no_prompt.md): 1 ファイル時
- [case-03_css_over4_text_select.md](case-03_css_over4_text_select.md): 4 ファイル以上
