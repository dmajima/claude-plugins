# add-design-pptx 実行手順

環境構築は `setup.md` を参照すること。

> **実行シェルの注意**: `convert_pptx.py` は python-pptx を使うため、Windows の `PowerShell` ツール経由の
> 直接起動ではハングする既知事象がある。本手順のコマンドは **Bash ツール経由** で実行すること。
> Bash 経由でも timeout 付きで起動したい場合はラッパー
> `${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-pptx/run_via_job.sh` を使用する（サンプル変換の起動にも利用可）。

## 1. 要件確定

対話モードでは以下を確定する（非対話モードは引数値をそのまま使う）。

| 項目 | 確認内容 | 制約 |
|------|---------|------|
| デザイン名 | kebab-case の英名（例: `dark-console`） | 予約名 `default` / `template` 不可、既存テーマ名との重複不可 |
| コンセプト | 配色の方向性・用途（例: ダーク系、コーポレート系） | — |
| 変更範囲 | 色のみ / フォント含む / サイズ・レイアウト含む | 迷ったら色のみから始める |

既存テーマ名の重複チェックは [`../../../references/design-locations.md`](../../../references/design-locations.md) の探索順序で
`assets/pptx-themes/*.json` とローカルデザインディレクトリを走査して行う。

## 2. デフォルトテーマの取得

```bash
"$SESSION_DIR/workspace/.venv/Scripts/python" \
  "${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-pptx/convert_pptx.py" \
  --dump-default-theme > "$SESSION_DIR/workspace/default-theme.json"
```

出力された JSON がデフォルトデザインの全パラメータ。新テーマはここから **変更するキーだけ** を部分指定で書く。

## 3. テーマ JSON の生成

`theme-schema.md` のスキーマに従い `$SESSION_DIR/workspace/<design-name>.json` を生成する。

設計ガイドライン:

- 変更しないキーは書かない（部分指定・差分最小）
- `name` / `description` にテーマ名とコンセプトを記載する
- `code_bg` を暗色にする場合は `code_text` / `code_border` / `syntax_palette` 全体を明色系に調整する
- `primary` を明色にする場合は `on_primary` を暗色にする（タイトル帯の可読性）

### 構図（レイアウト構造）を変更する場合

色・フォントだけでなく表紙・本文見出し部のレイアウト自体を変えたい場合は、
`theme-schema.md` の `composition` セクション仕様に従う。

1. `theme-schema.md` の **既定構図リファレンス** を種に、変更したい部位（`cover` /
   `content_header`）の `shapes` / `title` / `content_top` を設計する（部位は丸ごと置換）
2. 色は hex 直書きより **色トークン**（`primary` / `accent` / `hr` 等）を優先する
   （テーマ配色・`--primary-color` に自動追従するため）
3. 右端まで届く幅は `"full"` / `"sym"` トークンで書く（4:3 でも破綻しない）
4. shapes・テキストは `content_top` より上に収める（本文との重なり防止）
5. 手順 4 の検証で PASS を確認後、手順 5 のサンプル変換で座標・重なり・
   スライド分割数を実際の PPTX で確認する（構図変更時はスライド分割の縦積算も
   `content_top` 基準に変わる点に注意）

## 4. スキーマ検証

```bash
"$SESSION_DIR/workspace/.venv/Scripts/python" \
  "${CLAUDE_PLUGIN_ROOT}/references/scripts/add-design-pptx/validate_theme.py" \
  "$SESSION_DIR/workspace/<design-name>.json"
```

- `RESULT: PASS` を確認する。`[INFO] overrides ...` で意図したキーだけが変更されていることも確認する
- `RESULT: FAIL` の場合はエラーメッセージ（未知キー・不正色など）に従い JSON を修正して再検証する

## 5. サンプル変換（動作確認）

見出し・段落・箇条書き・コードブロック・表・水平線を含むサンプル MD を `workspace/` に用意し、実変換する。

```bash
"$SESSION_DIR/workspace/.venv/Scripts/python" \
  "${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-pptx/convert_pptx.py" \
  "$SESSION_DIR/workspace/sample.md" \
  "$SESSION_DIR/workspace/sample-<design-name>.pptx" \
  --theme "$SESSION_DIR/workspace/<design-name>.json"
```

- `Generated: ...` の成功出力を確認する
- 生成された PPTX をユーザーに提示し、デザインの見た目を確認してもらう（対話モード時）

## 6. 配置

[`../../../references/design-locations.md`](../../../references/design-locations.md) の節 4 に従い配置先を判定する。

| モード | 配置先 |
|-------|--------|
| 開発モード（convert-doc ソースリポジトリ内） | `<repo_root>/plugins/convert-doc/assets/pptx-themes/<design-name>.json` |
| 利用者モード | `<designs>/pptx-themes/<design-name>.json`（`<designs>` は design-locations.md 節 3） |

- 配置先ディレクトリが無ければ作成する
- 判定結果と配置先パスをユーザーに提示し、承認を得てからコピーする（対話モード時）
- 同名ファイルが既にある場合は無確認で上書きしない

## 7. 使い方案内

配置完了後、以下を提示する。

- `convert-pptx` スキル実行時にテーマ選択肢として表示されること
- 明示指定する場合のコマンド例: `--theme "<配置先絶対パス>"`

## トラブルシューティング

| 症状 | 対応 |
|------|------|
| `theme: unknown key ...` | キー名のタイポ。`theme-schema.md` の表と `--dump-default-theme` の出力で正しいキー名を確認 |
| `theme: ... invalid hex color` | 色は `#RGB` / `#RRGGBB` 形式の文字列で指定 |
| `theme: ... expected a positive number` | `font_sizes_pt` / `layout_in` は 0 より大きい数値のみ |
| `theme: 'composition...' expected a color token ...` | `composition` の色はトークン名（`colors` のキー名）か hex。トークン名のタイポを確認 |
| `theme: 'composition...' is missing required key ...` | `cover` は `title`+`subtitle`、`content_header` は `title`+`content_top` が必須 |
| 変換時 `Warning: ... title_band_height is not used` | `composition.content_header` 上書き時は `layout_in.title_band_height` が効かない。どちらかに片寄せする |
| 変換時 `Warning: composition shape ... was skipped` | `"sym"` 幅が負に解決された（`x` が大きすぎる）。`x` を小さくするか実数幅で指定 |
| サンプル変換でスライドがはみ出す | `layout_in.title_band_height` / `content_padding` / `composition.content_header.content_top` の変更が原因。デフォルトに戻すか小さくする |
| 生成 PPTX の文字が読めない（コントラスト不足） | `code_bg`×`code_text`×`syntax_palette`、`primary`×`on_primary` の組み合わせを調整 |
