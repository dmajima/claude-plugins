# Case 35: `verify_md.py` コネクタ閾値 5 件境界値

## 入力（3 パターン）

| パターン | PPTX コネクタ数 | MD Mermaid edges | 期待判定 |
|---|---|---|---|
| 35a | 4 | 0 | PASS（5 未満なので `connectors` 検証スキップ）|
| 35b | 5 | 0 | FAIL（5 以上 + edges=0、`failures` に追加）|
| 35c | 5 | 3 | PASS（edges > 0）|

- オプション: `--report <セッション>/coverage_report.json --threshold 0.85`

## 期待動作

1. `verify` で PPTX のコネクタ数 (`begin` / `end` が両方設定済みのもの) と MD 内 Mermaid edges をカウント
2. 判定式 `pptx_conn_total >= 5 and mermaid_edge_total == 0` を評価
3. 35a: `4 >= 5` が False → 検証スキップ → PASS
4. 35b: `5 >= 5 and 0 == 0` が True → `failures` に追加 → FAIL
5. 35c: `5 >= 5 and 3 == 0` が False → PASS

## 期待出力

- 35a / 35c: `passed: true`、終了コード 0
- 35b: `passed: false`、終了コード 1、`failures` に `"connectors: pptx=5 but no Mermaid edges in MD"` を含む

## 分岐の根拠

`verify_md.py:verify`:
```python
if pptx_conn_total >= 5 and mermaid_edge_total == 0:
    failures.append(f"connectors: pptx={pptx_conn_total} but no Mermaid edges in MD")
```

「コネクタが 5 件以上ある場合のみ Mermaid 化を要求する」設計の境界。コネクタが少ない PPTX で Mermaid 化が行われなくても FAIL にしない仕様。

## 関連ケース

- [case-25a_verify_pass.md](case-25a_verify_pass.md): 通常 PASS
- [case-05_flowchart_mermaid.md](case-05_flowchart_mermaid.md): フロー図 Mermaid 化の正常系
- [case-14_no_mermaid_flag.md](case-14_no_mermaid_flag.md): `--no-mermaid` 指定時の挙動
