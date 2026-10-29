# Case 14: composition のスキーマ検証 FAIL → 修正リトライ

## 入力

- 生成したテーマ JSON の `composition` セクションに誤りがある状態。代表例:
  - 空の composition（`"composition": {}`）
  - `cover` の必須キー欠落（`title` はあるが `subtitle` が無い）
  - `shapes[0].color` の色トークンタイポ（例: `"primaly"`）
  - `title.align` の enum 違反（例: `"middle"` — `anchor` と取り違え）

## 期待動作

1. `validate_theme.py` が composition 固有のエラーを出力し exit 1。それぞれ:
   - `[FAIL] theme: 'composition' must define at least one of: cover, content_header ...`
   - `[FAIL] theme: 'composition.cover' is missing required key 'subtitle'`
   - `[FAIL] theme: 'composition.cover.shapes[0].color': expected a color token (...) or a hex string ...`
   - `[FAIL] theme: 'composition.cover.title.align': expected one of: left, center, right ...`
2. エラーメッセージのパス表記（`composition.cover.shapes[0].color` 等）から該当箇所を特定して修正する
3. 再度 `validate_theme.py` を実行し `RESULT: PASS` を得る
4. **PASS になるまで配置に進まない**

## 期待出力

- 最終的に PASS したテーマ JSON のみが配置される
- FAIL のまま配置された形跡がない

## 分岐の根拠

`SKILL.md`「重要な制約」:
> テーマ JSON は必ず `validate_theme.py` の PASS とサンプル変換の成功を確認してから配置する

`references/theme-schema.md`「composition（構図）」:
> 未知キーは他セクション同様エラー（タイポ検出）
> `composition` を書く場合、`cover` / `content_header` の少なくとも一方が必須（空オブジェクトはエラー）
> `cover` を上書きする場合 `title` / `subtitle` は必須、`content_header` を上書きする場合 `title` / `content_top` は必須

## 関連ケース

- [case-03_schema_error_retry.md](case-03_schema_error_retry.md): colors / syntax_palette 系の検証エラー（composition 以外のセクション）
- [case-13_composition_theme.md](case-13_composition_theme.md): composition の正常系
- [case-15_composition_warnings.md](case-15_composition_warnings.md): 検証は PASS するが変換時に警告が出る系
