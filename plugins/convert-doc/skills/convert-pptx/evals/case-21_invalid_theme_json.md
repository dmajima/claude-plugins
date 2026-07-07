# Case 21: 変換時の不正テーマ JSON → exit 1

## 入力

- 入力 MD: 任意
- オプション: `--theme <path>` に以下のいずれかを指定
  - 存在しないファイル
  - JSON 構文エラーのファイル
  - 未知キーを含むファイル（例: `{"colors": {"primaryy": "#112233"}}`）
  - 不正な色値（例: `{"colors": {"primary": "zzz"}}`）

## 期待動作

1. `load_theme` が `ValueError` を送出する
2. `main()` が捕捉し、stderr に `Error: theme: ...`（原因を特定できるメッセージ）を出力
3. `sys.exit(1)` で終了（`--primary-color` 不正の exit 2 とは異なる経路）

## 期待出力

- 標準エラー: `Error: theme: unknown key 'colors.primaryy' (allowed: ...)` 等
- 終了コード: 1
- 出力 PPTX: 生成されない

## 分岐の根拠

`references/procedures.md`「変換スクリプト実行」:
> 不正なテーマ（未知キー・不正色・JSON 構文エラー）は exit 1 でエラーメッセージを出力する

※ `add-design-pptx` の case-03（`validate_theme.py` の FAIL）はデザイン**作成時**の検証ツールの分岐であり、
本ケースは**変換時**に `--theme` へ直接不正 JSON を渡した場合の `convert_pptx.py` 本体の分岐（別コードパス）。

## 関連ケース

- [case-07_invalid_primary_color.md](case-07_invalid_primary_color.md): `--primary-color` 不正（exit 2・argparse 経路）
