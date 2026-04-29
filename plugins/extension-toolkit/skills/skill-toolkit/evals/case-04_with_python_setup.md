# Case 04: Python venv 付きスキル作成

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "Python を使うスキル `data-analyzer` を作って" |
| 引数 | `data-analyzer --python` |
| フラグ | `--python` |
| 既存状態 | `data-analyzer` スキルが未存在 |

## 期待動作

### Phase 1: パラメータ確認

通常のパラメータ確認に加え、`requirements.txt` に記載する依存パッケージを確認。

### Phase 2: テンプレート展開

`templates/skill/` のうち `scripts/setup/{requirements.txt, setup_venv.sh, teardown_venv.sh}` も含めてコピー。`references/setup.md` も生成。

### Phase 3: requirements.txt 充填

ユーザ指定の依存パッケージで `requirements.txt` を上書き（バージョン固定推奨）。

### Phase 4: 検証

- 通常チェックに加え、`scripts/setup/` の 3 ファイルが揃っているか
- `references/setup.md` が存在するか
- `procedures.md` 冒頭で `setup.md` を参照しているか

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | 通常一式 + `scripts/setup/{requirements.txt, setup_venv.sh, teardown_venv.sh}` + `references/setup.md` |
| 標準出力（要約） | 「`data-analyzer` スキルを作成（Python venv 構成付き）」+ venv 構築コマンド案内 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは `--python` フラグの有無 である。

## 関連ケース

- `case-01_new_skill_interactive.md`（Python なし）
