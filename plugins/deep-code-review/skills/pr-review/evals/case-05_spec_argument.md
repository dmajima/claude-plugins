# case-05 spec 引数指定時の仕様整合性チェック付きレビュー

引数 spec=<path> で仕様書を明示指定してレビューするケース。指定された仕様書が期待挙動の最高優先の根拠として使用される。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "PR #123 をレビューして spec=docs/specs/order.md" |
| モード | 対話 |

## 分岐の根拠

SKILL.md 入力表「仕様書パス: spec=<path1>[,<path2>...]（期待挙動の根拠。未指定時は自動推論）」。code-review-spec-inference SKILL.md Step 1 の情報源優先順位（spec= 明示仕様書が priority 1）、code-review スキルの references/flow/flow.md Step 0-P-3 / Step 2（仕様書読み込み）。

## 期待動作

- spec=docs/specs/order.md を解析し、指定パスの仕様書を読み込む
- Step 3.5: code-review-spec-inference へ spec 引数を渡し、明示仕様書を最高優先の情報源（priority 1）として期待挙動サマリを構築する
- inputs フォルダ未作成の場合は指定仕様書から inputs フォルダを作成して保存する（code-review references/flow/flow.md Step 0-P-3）
- code-review への委譲時に spec_summary（最大 4,000 文字）を渡し、code-review-implementation の追加観点とする（code-review references/flow/flow.md Step 2）
- 仕様と実装の不整合（実装漏れ・仕様逸脱）を指摘として報告する
- 統合サマリの集計セクション「参照仕様書」に指定ファイルを記載する

## 関連ケース

- case-01: spec 未指定時（PR description からの自動推論）
