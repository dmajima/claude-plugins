# convert-from-pptx CLI オプション

`convert_from_pptx.py` の全コマンドラインオプション。

## 必須引数

| 引数 | 内容 |
|------|------|
| `<入力PPTX>` | 変換対象の PPTX ファイルパス |
| `<出力MD>`（省略可） | 出力 Markdown ファイルパス。省略時は入力と同ディレクトリ・同名で `.md` 拡張子 |

## オプション

| オプション | 省略値 | 内容 |
|-----------|-------|------|
| `--structured-json <PATH>` | なし | Phase 1 用の機械抽出 JSON 出力先（単一 JSON 全部入り） |
| `--per-slide-json <DIR>` | なし | スライドごとに `slide-NN.json` を分割出力 + `metadata.json`（中〜大規模 PPTX 向け） |
| `--compact-view <DIR>` | なし | スライドごとに人間 / LLM 可読の簡潔ビュー `slide-NN.txt` を出力（Phase 2 で軽量に Read） |
| `--json-only` | OFF | JSON / ビューのみ出力（Markdown 直接生成をスキップ。Phase 2 で Claude が MD 化する場合に指定） |
| `--images-dir <DIR>` | `<出力MD basename>_images/` | 画像抽出先（出力 MD ディレクトリ配下に強制） |
| `--no-mermaid` | OFF | フロー図 / SmartArt の Mermaid 変換を無効化（フォールバック用） |
| `--include-notes` | OFF | スピーカーノートを `> [!NOTE]` ブロックとして含める |
| `--include-hidden` | OFF | 非表示スライドも出力に含める |
| `--no-first-slide-as-title` | ON | 1 枚目も `## スライド1` として H2 扱い |
| `--max-image-size <BYTES>` | `5242880`（5 MiB） | 画像 1 枚あたりの最大バイト数。超過時はメタ情報のみ |

## オプション選択ガイド

| 用途 | 推奨オプション |
|-----|-------------|
| 小規模 PPTX（〜30 スライド）の標準変換 | （オプションなし） |
| Phase 2 で Claude が JSON 解釈して MD を作る | `--structured-json <PATH> --json-only` |
| 中規模 PPTX（30〜100 スライド）でメイン側 Read 分散 | `--per-slide-json <DIR> --compact-view <DIR> --json-only` |
| 大規模 PPTX（100+ スライド）でサブエージェント並列分担 | 中規模と同じオプション + サブエージェント担当範囲を分割 |
| ノート付き資料 | `--include-notes` |
| 非表示スライド含む完全変換 | `--include-hidden` |
| LLM 介入なしの自動変換（CI 等） | （オプションなし、Python 単独で MD 直接生成） |

## 検証スクリプト `verify_md.py`

Phase 3 の検証は `verify_md.py` を別途実行する。

| 引数 / オプション | 既定値 | 内容 |
|-----------------|-------|------|
| `<入力PPTX>` | （必須） | 元 PPTX |
| `<生成MD>` | （必須） | 検証対象 Markdown |
| `--report <PATH>` | なし | カバレッジレポート JSON の出力先 |
| `--threshold <FLOAT>` | `0.85` | カバレッジ閾値（`text_coverage` / `table_cell_coverage` の下限） |
| `--max-missing-shown <INT>` | `20` | コンソール表示する missing 件数の上限 |

詳細は [`validation.md`](validation.md) を参照。
