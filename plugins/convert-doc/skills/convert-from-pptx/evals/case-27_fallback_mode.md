# Case 27: フォールバックモード（Python 単独 Markdown 直接生成）

## 入力

- 入力 PPTX: 3 スライド構成の有効な PPTX
- 出力 MD: `output.md`
- オプション: なし（`--structured-json` / `--json-only` も未指定）
- 文脈: LLM 呼び出し不可（CI / バッチジョブ等の自動処理コンテキスト）

## 期待動作

1. `_validate_pptx` で入力 PPTX を検証
2. `PPTXMarkdownConverter.convert` を呼び、Python 側のヒューリスティック（フォントサイズ統計・色判定・位置統計）で装飾フィルタ・タイトル推定・Mermaid 化を実行
3. Phase 2（Claude 解釈）を経ずに直接 Markdown 出力
4. 出力品質は対話モード（2 フェーズ）より劣るが、人手介入なしで完結
5. 終了コード: 0

## 期待出力

`output.md`:
```markdown
# プレゼンタイトル

## 概要

- 箇条書き 1
- 箇条書き 2

## 詳細

詳細本文...
```

## 分岐の根拠

`SKILL.md` の「実行フロー（フォールバック・Python 単独）」セクション:
```
LLM 呼び出しが行えない自動処理コンテキストでは、従来通り Python 単独で Markdown を直接生成する
```

`convert_from_pptx.py:main` の通常パス（`--structured-json` / `--json-only` 未指定時）。

## 関連ケース

- [case-01_normal_with_title.md](case-01_normal_with_title.md): 2 フェーズの標準変換
- [case-26_interactive_mode.md](case-26_interactive_mode.md): 対話モード
- [case-23a_structured_json_normal.md](case-23a_structured_json_normal.md): Phase 1 JSON 出力
