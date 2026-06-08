# Case 54: 非対話モード（パス指定による確認スキップ）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "C:/docs/spec.pptx をMarkdownに変換" |
| モード | 非対話 |
| 入力パス | `C:/docs/spec.pptx`（明示指定） |

## 期待動作

- convert-from-pptx スキルが起動する
- 入力 PPTX パスが起動フレーズ内で明示されているため、ファイル確認の `AskUserQuestion` をスキップする
- Phase 1 で Python による構造化 JSON 抽出を実行する
- Phase 2 で Claude が JSON を解釈して Markdown を生成する
- 出力先はデフォルト解決（`<入力ベース名>.md`）

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | `spec.md`（入力パスから推定されるデフォルト出力先） |
| 対話プロンプト | なし（パス指定済みのため確認をスキップ） |

## 分岐の根拠

SKILL.md の実行モード判定表で「引数で入力 PPTX / 出力 MD / 全オプションが指定 / `--non-interactive` 相当 → 非対話モード」に該当。入力パスが起動フレーズに含まれるため確認を省略し、デフォルト値で進行する分岐。

## 関連ケース

- [case-51_trigger_pptx_to_md.md](case-51_trigger_pptx_to_md.md): パス未指定の対話モードとの対比
- [case-36_default_md_output_path.md](case-36_default_md_output_path.md): デフォルト出力パス解決の詳細
