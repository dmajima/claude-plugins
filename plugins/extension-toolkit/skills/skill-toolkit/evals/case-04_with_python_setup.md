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

`references/templates/skill/` のうち `references/setup.md`（環境構築手順 + 依存パッケージリスト）と `scripts/deps/requirements.txt`（依存リストファイル、任意）をコピー。**venv 構築・撤去スクリプトはコピーしない**（`environment-setup-toolkit` に委譲）。

### Phase 3: 依存リスト充填

ユーザ指定の依存パッケージを `scripts/deps/requirements.txt` に書き出す（バージョン固定推奨）。`references/setup.md` の依存パッケージセクションも同期する。

### Phase 4: 検証

- 通常チェックに加え、`scripts/deps/requirements.txt` または `references/setup.md` に依存リストが保管されているか
- `references/setup.md` 内で `environment-setup-toolkit` への委譲が明記されているか
- スキル内に `setup_venv.sh` / `teardown_venv.sh` が **配置されていない** こと（責務単一化）
- `procedures.md` 冒頭で `setup.md` を参照しているか

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | 通常一式 + `scripts/deps/requirements.txt` + `references/setup.md`（venv 構築・撤去スクリプトはなし） |
| 標準出力（要約） | 「`data-analyzer` スキルを作成（Python 依存リスト構成付き、venv 構築は environment-setup-toolkit に委譲）」+ 利用例 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは `--python` フラグの有無 である。

## 関連ケース

- `case-01_new_skill_interactive.md`（Python なし）
