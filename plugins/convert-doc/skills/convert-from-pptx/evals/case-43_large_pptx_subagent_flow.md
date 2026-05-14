# Case 43: 大規模 PPTX（100 スライド超）でのサブエージェント並列分担フロー

## 入力

- 入力 PPTX: 120 スライド構成の有効な PPTX
- 出力 MD: `<セッション>/output.md`
- 文脈: ユーザの自然言語依頼「この大規模 PPTX を Markdown に変換して」（対話モード）

## 期待動作

1. SKILL.md の「サイズ別フロー選択」表に従い、スライド数 120 > 100 で **大規模** フローと判定
2. Phase 1: `convert_from_pptx.py --per-slide-json <セッション>/json/ --compact-view <セッション>/views/ --json-only` を実行
3. 出力: `metadata.json` + `slide-001.json` 〜 `slide-120.json` + `slide-001.txt` 〜 `slide-120.txt` + 画像
4. Claude メインコンテキストが `metadata.json` を Read してスライド構成を把握
5. スライドを 4 範囲（1〜30 / 31〜60 / 61〜90 / 91〜120）に分割
6. サブエージェント 4 名を **並列起動** し、各エージェントに `views/slide-NN.txt` の担当範囲を Read で読み込み + Markdown ブロック生成を委譲
7. 各サブエージェントは `parts/part-{range}.md` を出力
8. メインコンテキストが全 part を統合して最終 `output.md` に書き込み
9. Phase 3: `verify_md.py` で統合 MD を元 PPTX と機械的に突き合わせて検証
10. 終了コード: 0

## 期待出力

```
<セッション>/json/metadata.json
<セッション>/json/slide-001.json 〜 slide-120.json
<セッション>/views/slide-001.txt 〜 slide-120.txt
<セッション>/parts/part-1-30.md
<セッション>/parts/part-31-60.md
<セッション>/parts/part-61-90.md
<セッション>/parts/part-91-120.md
<セッション>/output.md（統合済み）
<セッション>/output_images/（共通画像）
<セッション>/coverage_report.json（Phase 3 結果）
```

## 分岐の根拠

`SKILL.md` の「サイズ別フロー選択」表:
```
| 大規模 | スライド数 100 超 | per-slide JSON + サブエージェント並列分担 | references/large-pptx-workflow.md 節 3 |
```

`references/large-pptx-workflow.md` 節 3 の手順:
- サブエージェントへの担当範囲分割
- Mermaid ID 衝突回避 (range prefix)
- 章番号は H3 以下に限定
- 統合 MD に対して Phase 3 検証

このケースは Claude メインコンテキスト側の **判断分岐** を検証する evals であり、Python スクリプト単体ではなく「スキルの使い方」レベルの動作確認に位置付けられる。

## 関連ケース

- [case-24a_per_slide_json.md](case-24a_per_slide_json.md): per-slide JSON の単体検証
- [case-24b_compact_view.md](case-24b_compact_view.md): compact-view の単体検証
- [case-25a_verify_pass.md](case-25a_verify_pass.md): Phase 3 検証の正常系
- [case-26_interactive_mode.md](case-26_interactive_mode.md): 対話モード
