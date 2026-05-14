# Case 45: 中規模 PPTX（30〜100 スライド）でのメイン逐次 Read フロー

## 入力

- 入力 PPTX: 50 スライド構成の有効な PPTX
- 出力 MD: `<セッション>/output.md`
- 文脈: ユーザの自然言語依頼「この中規模 PPTX を Markdown に変換して」（対話モード）

## 期待動作

1. SKILL.md の「サイズ別フロー選択」表に従い、スライド数 50（30〜100 の範囲）で **中規模** フローと判定
2. Phase 1: `convert_from_pptx.py --per-slide-json <セッション>/json/ --compact-view <セッション>/views/ --json-only` を実行
3. 出力: `metadata.json` + `slide-01.json` 〜 `slide-50.json` + `slide-01.txt` 〜 `slide-50.txt`
4. Claude メインコンテキストが `metadata.json` を Read してスライド構成を把握
5. **メイン側で逐次 Read**: スライドごとに `views/slide-NN.txt`（軽量・コンパクトビュー優先）を Read
6. メインコンテキストが各スライドの Markdown ブロックを順次組み立て
7. 最終 `output.md` に統合書込
8. Phase 3: `verify_md.py` でカバレッジ検証
9. 終了コード: 0

**サブエージェントは起動しない**（中規模では不要、大規模 100+ スライドで初めてサブエージェント分担）。

## 期待出力

```
<セッション>/json/metadata.json
<セッション>/json/slide-01.json 〜 slide-50.json
<セッション>/views/slide-01.txt 〜 slide-50.txt
<セッション>/output.md（統合済み）
<セッション>/output_images/
<セッション>/coverage_report.json
```

## 分岐の根拠

`SKILL.md` の「サイズ別フロー選択」表:
```
| 中規模 | スライド数 30〜100 | per-slide JSON + compact view（メインで逐次 Read） | references/large-pptx-workflow.md 節 2 |
```

`references/large-pptx-workflow.md` 節 2 の手順:
- per-slide JSON + compact-view を出力
- コンパクトビュー（軽量）をメイン側で逐次 Read
- 細部が必要なときのみ JSON を補助参照
- サブエージェント並列分担は不要

このケースは Claude メインコンテキストの「中規模判定」分岐を検証する evals。case-43（大規模・サブエージェント並列）との対比で、フロー選択の境界を明確にする。

## 関連ケース

- [case-24a_per_slide_json.md](case-24a_per_slide_json.md): per-slide JSON 出力の単体検証
- [case-24b_compact_view.md](case-24b_compact_view.md): compact-view の単体検証
- [case-43_large_pptx_subagent_flow.md](case-43_large_pptx_subagent_flow.md): 大規模（100+）のサブエージェント並列
- [case-26_interactive_mode.md](case-26_interactive_mode.md): 対話モード
