# Case 02: 新規外形 + 既存スキル移管

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "新規プラグイン `dev-toolkit` に既存スキル `code-formatter` を含めて作成" |
| 引数 | `dev-toolkit --include skill:code-formatter` |
| フラグ | なし |
| 既存状態 | `dev-toolkit` 未存在、`code-formatter` スキルが `~/.claude/skills/` 配下に存在 |

## 期待動作

### Phase 1: 外形作成

case-01 と同じ手順で `dev-toolkit` 外形を作成。`skills/` サブディレクトリを含める。

### Phase 2: 既存資産特定

`code-formatter` スキルの所在を Glob で確認。プロジェクト・グローバル両方に存在する場合は対話で選択。

### Phase 3: 移管実行

スキルディレクトリ全体を `plugins/dev-toolkit/skills/code-formatter/` にコピー。

### Phase 4: パスポータビリティチェック

移管後ファイルを Grep し、ハードコードパス検出。検出時はユーザに修正方針確認。

### Phase 5: 検証

- 元 `code-formatter` ディレクトリが無傷
- 移管後の `SKILL.md` の `name` がディレクトリ名と一致
- `references/` `agents/` の構造が維持されている

### Phase 5.5: ADR-024 / ADR-025 準拠化（移管元が旧構造の場合）

移管元スキルが旧構造（スキル直下 `scripts/` または `requirements.txt`）を持つ場合、新ルールへ自動変換する。下表の左列はいずれも **旧構造（ADR-024/025 で廃止済）** であり、新規スキルでは使用しない:

| 旧構造（廃止済・移管元検出時のみ） | 変換後（新ルール） |
|------------------------------|------------------|
| `code-formatter/scripts/{業務}/*.py` | `code-formatter/references/scripts/{業務}/*.py` |
| `code-formatter/scripts/setup/setup_venv.sh` または `setup_venv.sh` | 削除（プラグイン直下 `dev-toolkit/references/scripts/setup/setup_venv.sh` に統合 / 既存があれば差分マージ。Bash 標準、shell-preference.md 準拠） |
| `code-formatter/scripts/deps/requirements.txt` または `code-formatter/scripts/setup/requirements.txt` | プラグイン直下 `dev-toolkit/references/scripts/setup/requirements.txt` にマージ（バージョン競合あればユーザ確認） |
| 旧スキル単位 venv 構築前提のドキュメント記述 | プラグイン直下スクリプトを呼ぶ表現に書き換え |

#### バージョン競合時のユーザ判断分岐

`requirements.txt` マージで同名パッケージのバージョン競合を検出した場合:

| ユーザ選択 | 期待動作 |
|-----------|--------|
| 新版で上書き | プラグイン直下 requirements.txt の該当行を新版に更新、移管元 requirements.txt は削除 |
| 既存版を維持 | プラグイン直下 requirements.txt は **変更しない**、移管元 requirements.txt も削除し、ユーザに「移管スキルが要求するバージョンが異なる旨」を警告 |
| キャンセル | 移管全体をロールバック: (1) 移管先 `plugins/dev-toolkit/skills/code-formatter/` を **削除**、(2) プラグイン直下 `requirements.txt` は **変更しない**、(3) 元の `code-formatter` ディレクトリは無傷のまま、(4) ユーザに「移管をキャンセルした旨」と「依存競合の詳細（パッケージ名・要求バージョン・既存バージョン）」を提示 |

### Phase 6: 引き渡し

`marketplace-publish` への接続を提案。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `dev-toolkit` 外形一式 + `plugins/dev-toolkit/skills/code-formatter/` ディレクトリ全体 |
| 標準出力（要約） | 「`dev-toolkit` プラグイン作成 + `code-formatter` スキル移管完了」 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは `--include` 引数で移管対象指定 である。

## 関連ケース

- `case-01_new_shell_only.md`（新規外形のみ、移管なし）
- `case-03_add_to_existing.md`（既存プラグインへの追加配置）
