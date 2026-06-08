# case-09 Markdown を PPTX に変換

ユーザーが Markdown ファイルを PowerPoint に変換するよう依頼した場合の基本トリガー。

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "この Markdown を PowerPoint に変換して" |
| モード | 対話 |

## 期待動作

- convert-pptx スキルが起動する
- 入力 MD ファイルのパスを確認する
- H1 をタイトルスライド、H2 を新規スライド区切りとして PPTX を生成する
- 16:9 ワイドスクリーン・ネイビータイトル帯のデフォルトデザインで出力する

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | 16:9 ワイドスクリーンの PPTX ファイル（ネイビータイトル帯デザイン） |

## 分岐の根拠

SKILL.md の実行モード判定表で自然言語依頼による対話モードに該当。description の「Markdown を PowerPoint に変換」パターンに合致し、スキルトリガーとして認識される。

## 関連ケース

- [case-01_normal_with_h2.md](case-01_normal_with_h2.md): H2 複数の標準変換
- [case-10_trigger_slide_creation.md](case-10_trigger_slide_creation.md): スライド作成トリガー
