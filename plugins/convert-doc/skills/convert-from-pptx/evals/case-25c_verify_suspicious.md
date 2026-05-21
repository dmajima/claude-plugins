# Case 25c: `verify_md.py` 誤転記候補（suspicious_md_phrases）検出

## 入力

- 入力 PPTX: 元の PPTX（テキスト「会社設立は 2010 年」等を含む）
- 生成 MD: PPTX の本文に加えて「会社設立は 2005 年」のように **存在しない事実** を追加した Markdown
- オプション: `--report <セッション>/coverage_report.json --threshold 0.85`

## 期待動作

1. `verify()` でカバレッジ計算（PPTX → MD は問題なし、`text_coverage >= 0.85`）
2. MD 内のフレーズを抽出して PPTX 全テキスト連結文字列と照合
3. `len(phrase) >= 16` かつ Mermaid 構文等の偽陽性除外を経たフレーズで、PPTX に存在しないものを `suspicious_md_phrases` に追加
4. `suspicious_md_phrases` は警告扱い（FAIL にはしない設計）
5. `passed: true`（カバレッジ閾値達成）だが、標準出力に suspicious フレーズを表示
6. 終了コード: 0（suspicious は警告のため exit 1 にしない）

## 期待出力

```jsonc
{
  "summary": {
    "text_coverage": 0.9500,
    "suspicious_md_phrase_count": 1,
    ...
  },
  "suspicious_md_phrases": [
    "会社設立は 2005 年であり業界初の..."
  ],
  "failures": [],
  "passed": true
}
```

標準出力:
```
Suspicious MD phrases not found in PPTX (first 20):
  '会社設立は 2005 年であり業界初の...'

RESULT: PASSED
```

## 分岐の根拠

`verify_md.py:verify()`:
```python
suspicious_md_phrases: list = []
for phrase in md["phrases"]:
    if len(phrase) < 16:
        continue
    if any(tok in phrase for tok in ("![", "```", "http", "->", "flowchart", "subgraph", "<br")):
        continue
    cmp_phrase = phrase.replace("*", "").replace("`", "").strip()
    if len(cmp_phrase) < 16:
        continue
    if cmp_phrase not in pptx_all_text_norm:
        suspicious_md_phrases.append(cmp_phrase[:160])
```

`validation.md` 節 3.2 で Claude が分類すべき候補。誤転記（捏造）として削除すべきフレーズの代表例。

## 関連ケース

- [case-25a_verify_pass.md](case-25a_verify_pass.md): 通常 PASS
- [case-25b_verify_fail.md](case-25b_verify_fail.md): 閾値未達 FAIL
## 起動経路についての注記

`verify_md.py` も python-pptx を内部で使うため、`Start-Process -NoNewWindow` 直起動はハングする可能性がある。
詳細と回避策は [case-25a_verify_pass.md](case-25a_verify_pass.md) の「起動経路についての注記」を参照。
