# case-14 資料を HTML 化

ユーザーが作成した資料を HTML 化するよう依頼した場合のトリガー。

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "この資料を HTML にして" |
| モード | 対話 |

## 期待動作

- convert-html スキルが起動する
- 入力ファイルのパスを確認する
- 画像は base64 埋込、mermaid 図は SVG インラインで自己完結型 HTML を生成する
- 最終 HTML をセッションフォルダ直下に出力する

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | 自己完結型 HTML ファイル（画像 base64 埋込・mermaid SVG インライン） |

## 分岐の根拠

SKILL.md の実行モード判定表で「`/convert-html` または自然言語依頼 → 対話モード」に該当。description の「資料を HTML で出力」パターンに合致し、スキルトリガーとして認識される。

## 関連ケース

- [case-12_trigger_md_to_html.md](case-12_trigger_md_to_html.md): 基本的な変換トリガー
- [case-07_non_interactive_full_features.md](case-07_non_interactive_full_features.md): 非対話モードとの対比
