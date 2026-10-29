# Case 01: CSS が合算 1 ファイル → 選択プロンプトなし

> 前提の注意: v4.0.0 以降の配布状態ではサンプルデザイン `warm-paper.css` が
> `${CLAUDE_PLUGIN_ROOT}/assets/css/` に同梱されるため、クリーンインストールの既定は
> 合算 2 ファイル（→ [case-02](case-02_css_multi_interactive.md) の分岐）になる。
> 本ケースは「合算 1 ファイル」分岐の仕様検証であり、サンプルを除去したカスタム構成や
> ローカル・スキル側に追加が無い最小構成で成立する（README ADR-004 のトレードオフ参照）。

## 入力

- 入力 MD: 任意（最小限の `# タイトル` のみで可）
- `${CLAUDE_SKILL_DIR}/assets/css/`: 空、または `template.css` のみ
- `${CLAUDE_PLUGIN_ROOT}/assets/css/`: `template.css` のみ（サンプルデザインを除去した構成）
- ローカルデザインディレクトリ: `.css` なし
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
