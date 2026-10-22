# Case 02: 未導入リポジトリへの新規導入（非対話モード）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | `/design-init --non-interactive` |
| 引数 | なし（または対象 projectId を引数で指定） |
| フラグ | `--non-interactive` |
| 既存状態 | git リポジトリ。`/design-login` 認可済み。`.claude/design-bridge.json` なし。`jq` が利用できない |

## 期待動作

### Phase 1: 前提チェック
- プロジェクトルートを特定する
- `jq` が無いことを検出し、「フックが動作しない」旨を明示する
- 非対話モードのため続行可否をユーザに問わず、警告を残したうえで既定の方針で進行する

### Phase 2: Claude Design プロジェクトの決定
- 引数で projectId が指定されていればそれを採用する
- 指定が無い場合は `list_projects` の結果から既定値として確定し、`AskUserQuestion` を発火させない
- いずれの場合も `get_project` で `type` が design-system であることを確認する

### Phase 3〜6: 構成・設定・gitignore・venv
- `specs/screens` `specs/assets` `mocks` を既定値のまま作成する
- `.claude/design-bridge.json` を既定値（`blockLimit: 3`、`viewport: 1280x800`、既定の `watch`）で生成する
- `.gitignore` に `.claude/.local/` が無ければ追記する（非対話のため確認を挟まない）
- venv を構築し、`playwright install chromium` が別途必要である旨を伝える

### Phase 7: 導入完了の報告
- 既定値で確定した項目と、`jq` 不在によりフックが動作しないことを警告として併記する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `.claude/design-bridge.json`、`specs/screens/`、`specs/assets/`、`mocks/`、`.gitignore` への追記 |
| 標準出力（要約） | 既定値で確定した構成一覧、紐付けた Claude Design プロジェクト名と ID、`jq` 不在によりフックが動作しない旨の警告、次のアクション |
| 終了状態 | 成功（警告あり） |

## 禁止事項（このケースで起きてはならないこと）

- 非対話モードで `AskUserQuestion` を発火させること
- `jq` 不在を黙って無視し、警告なしで完了報告すること
- `get_project` の型確認を省略すること（非対話でも必須）

## 分岐の根拠

このケースが分岐するトリガーは「実行モード判定 = 非対話（`--non-interactive` フラグあり、または引数で projectId まで指定）」である。実行モード判定表の非対話行に従い、確認を挟まず既定値で確定して進行する。あわせて実行フロー 1 の「`jq` の有無」検査が NG となる経路を扱う。

## 関連ケース

- [case-01](case-01_new_setup_interactive.md): 同じ新規導入の対話版（確認を挟む点が異なる）
- [case-03](case-03_existing_config_update.md): 設定ファイルが既にある場合（非対話でも無確認上書きはしない）
