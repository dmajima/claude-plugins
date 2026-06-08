# case-53 設計書 PPTX の解析

ユーザーが設計書の PPTX を解析・テキスト化するよう依頼した場合のトリガー。

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "設計書の PPTX を解析して Markdown にまとめて" |
| モード | 対話 |

## 期待動作

- convert-from-pptx スキルが起動する
- 入力 PPTX のパスを確認する
- 表・画像・フロー図を含む場合は GFM テーブル・画像参照・Mermaid 化を行う
- Phase 3 のカバレッジ検証で漏れがないか確認する

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | 設計書の構造を反映した Markdown ファイル（表・画像参照・Mermaid 図を含む） |

## 分岐の根拠

SKILL.md の実行モード判定表で「上記以外（自然言語依頼）→ 対話モード」に該当。description の「設計書 PPTX を解析」パターンに合致し、スキルトリガーとして認識される。

## 関連ケース

- [case-51_trigger_pptx_to_md.md](case-51_trigger_pptx_to_md.md): 基本的な変換トリガー
- [case-25a_verify_pass.md](case-25a_verify_pass.md): Phase 3 カバレッジ検証の詳細
