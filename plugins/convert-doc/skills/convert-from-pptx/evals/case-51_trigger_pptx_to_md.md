# case-51 PPTX を Markdown に変換

ユーザーが PPTX ファイルを Markdown に変換するよう依頼した場合の基本トリガー。

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "この PPTX を Markdown に変換して" |
| モード | 対話 |

## 期待動作

- convert-from-pptx スキルが起動する
- 入力 PPTX のパスをユーザーに確認する（未指定の場合）
- Phase 1 で Python による構造化 JSON 抽出を実行する
- Phase 2 で Claude が JSON を解釈して Markdown を生成する

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | 入力 PPTX に対応する Markdown ファイル（セッションフォルダ直下） |

## 分岐の根拠

SKILL.md の実行モード判定表で「上記以外（自然言語依頼）→ 対話モード」に該当。入力パス未指定のため `AskUserQuestion` でユーザに確認する分岐。

## 関連ケース

- [case-26_interactive_mode.md](case-26_interactive_mode.md): 対話モードの詳細フロー
- [case-52_trigger_slide_to_text.md](case-52_trigger_slide_to_text.md): 別表現でのトリガー
