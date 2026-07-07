# Case 03: 契約検証 FAIL → 修正リトライ

## 入力

- 生成した CSS が契約を満たしていない状態
  （例: `#lb-overlay` のスタイル欠落、`.toc-collapsed` 未定義）

## 期待動作

1. `validate_css.py` が `[FAIL] lightbox-js: #lb-overlay ...` 等を出力し exit 1
2. FAIL 行が示すセレクタ・契約を `css-contract.md` で確認し、CSS に追加する
3. 再度 `validate_css.py` を実行し `RESULT: PASS` を得る
4. **PASS になるまで配置に進まない**

## 期待出力

- 最終的に PASS した CSS のみが配置される
- FAIL のまま配置された形跡がない

## 分岐の根拠

`SKILL.md`「重要な制約」:
> 新デザインは必ず `validate_css.py`（ペア時 `validate_html.py` も）の PASS とサンプル変換の成功を確認してから配置する

## 関連ケース

- [case-09_breakpoint_preservation.md](case-09_breakpoint_preservation.md): ブレークポイント契約
