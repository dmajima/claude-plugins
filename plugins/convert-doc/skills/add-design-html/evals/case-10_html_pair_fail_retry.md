# Case 10: HTML ペア検証 FAIL → 修正リトライ

## 入力

- HTML ペア生成が必要なデザインで、生成した `<design-name>.html` が契約を満たしていない状態
  （例: `{{JS_BLOCK}}` プレースホルダの欠落、`class="doc-title"` を `class="doc-title-badge"` に改変、
  `{{TOC_SIDEBAR}}` を `{{JS_BLOCK}}` より後ろに配置）

## 期待動作

1. `validate_html.py` が `[FAIL] placeholder: {{JS_BLOCK}} is missing ...` 等を出力し exit 1
2. FAIL 行が示すプレースホルダ・骨格 DOM・順序の契約を `template.html` / `css-contract.md` で確認し、HTML を修正する
3. 再度 `validate_html.py` を実行し `RESULT: PASS` を得る
4. **CSS（`validate_css.py`）と HTML（`validate_html.py`）の両方が PASS になるまで配置に進まない**

## 期待出力

- 最終的に両検証 PASS した CSS + HTML ペアのみが配置される
- FAIL のまま配置された形跡がない

## 分岐の根拠

`SKILL.md`「重要な制約」:
> 新デザインは必ず `validate_css.py`（ペア時 `validate_html.py` も）の PASS とサンプル変換の成功を確認してから配置する

## 関連ケース

- [case-03_contract_fail_retry.md](case-03_contract_fail_retry.md): CSS 検証の FAIL リトライ
- [case-04_html_pair_generation.md](case-04_html_pair_generation.md): HTML ペア生成の成功フロー
