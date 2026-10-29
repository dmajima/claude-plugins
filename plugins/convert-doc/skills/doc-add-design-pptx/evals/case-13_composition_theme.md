# Case 13: composition（構図）付きテーマの作成

## 入力

- ユーザー依頼: 「executive 風のレイアウトの PPTX テーマを追加して。表紙は左バーなしで
  ゴールドの飾り線、本文は塗り帯なしのキーメッセージ形式にしたい」

## 期待動作

1. 色・フォントだけでは実現できない要望（レイアウト構造の変更）と判断し、
   `theme-schema.md` の `composition` セクション仕様を参照する
2. 既定構図リファレンス（`theme-schema.md`）を種に `cover` / `content_header` を設計する
   - 右端まで届く幅は `"full"` / `"sym"` トークンで記述（絶対値にしない）
   - 色はトークン名（`primary` / `accent` / `hr` 等）を優先
   - shapes・テキストを `content_top` より上に収める（下端装飾を除く）
3. `validate_theme.py` で PASS を確認する（`[INFO] overrides ...` に `composition` が
   1 項目として列挙される）
4. サンプル MD を実変換し、生成 PPTX の座標・重なり・スライド分割数を確認する
5. 既定構図との差分（変わった点）をユーザーに要約報告する

## 期待出力

- `composition` を含むテーマ JSON（検証 PASS）
- サンプル変換の成功（`Generated: ...`）
- 既定構図との差分説明（例: 表紙の左バー → ゴールドルール + 下端帯、
  本文の塗り帯 → キーメッセージ + ヘアライン、コンテンツ開始 1.1 → 1.35）

## 検証観点（機械確認可能）

```bash
# 構図リファレンスと実装の同期（テーマ作成とは独立に常時 PASS していること）
python "${CLAUDE_PLUGIN_ROOT}/references/scripts/add-design-pptx/check_default_composition.py"

# 作成テーマの検証（composition が overrides に列挙される）
python "${CLAUDE_PLUGIN_ROOT}/references/scripts/add-design-pptx/validate_theme.py" <theme.json>
```

## 分岐の根拠

`SKILL.md` 概要:
> 色・フォント・サイズに加えて構図（表紙・本文見出し部のレイアウト構造）も
> `composition` セクションで定義可能

`references/procedures.md`「3. テーマ JSON の生成 > 構図（レイアウト構造）を変更する場合」

## 関連ケース

- [case-02_noninteractive_full.md](case-02_noninteractive_full.md): 色のみの通常テーマ作成
- [case-09_layout_overflow_warning.md](case-09_layout_overflow_warning.md): レイアウト過大値の検知
  （`content_top` 過大時も同じ did-not-fit 警告が安全網になる）
