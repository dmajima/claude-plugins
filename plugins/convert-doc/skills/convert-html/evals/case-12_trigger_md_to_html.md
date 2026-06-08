# case-12 Markdown を HTML に変換

ユーザーが Markdown ファイルを HTML に変換するよう依頼した場合の基本トリガー。

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "この Markdown を HTML に変換して" |
| モード | 対話 |

## 期待動作

- convert-html スキルが起動する
- 入力 MD ファイルのパスを確認する
- CSS が複数存在する場合は選択 UI を表示する
- 自己完結型 HTML（画像 base64 埋込・mermaid SVG インライン）を生成する

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | 自己完結型 HTML ファイル（セッションフォルダ直下） |

## 分岐の根拠

SKILL.md の実行モード判定表で「`/convert-html` または自然言語依頼 → 対話モード」に該当。CSS 複数時は選択 UI、JS 機能カタログがあれば除外選択 UI を表示する分岐。

## 関連ケース

- [case-07_non_interactive_full_features.md](case-07_non_interactive_full_features.md): 非対話モードとの対比
- [case-13_trigger_design_doc_html.md](case-13_trigger_design_doc_html.md): 設計書 HTML 化トリガー
