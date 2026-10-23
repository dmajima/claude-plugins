# Case 02: 未導入リポジトリへの新規導入（非対話モード・jq 不在）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | `/design-init --non-interactive` |
| 引数 | なし（または対象 projectId を引数で指定） |
| フラグ | `--non-interactive` |
| 既存状態 | git リポジトリ。Python 3.9 以上が利用可。`/design-login` 認可済み。`.claude/design-bridge.json` なし。**`jq` が利用できない** |

## 期待動作

### Phase 1: 前提チェック
- プロジェクトルートを特定する
- Python 3.9 以上が利用可能であることを確認する
- `jq` が無いことを検出する。`jq` は任意依存であり、**導入自体は続行する**
- `jq` 不在の影響を正しく説明する。フックは動作するが `watch` 設定を読めないため、既定の監視対象（`specs` 配下の `.md` を spec、`mocks` 配下の `.html` を mock）へ縮退する。既定以外の構成にする場合は `jq` が必要である
- 非対話モードのため続行可否をユーザに問わず、警告を残したうえで既定の方針で進行する

### Phase 2: Claude Design プロジェクトの決定
- 引数で projectId が指定されていればそれを採用する
- 指定が無い場合は `list_projects` の結果から既定値として確定し、`AskUserQuestion` を発火させない
- いずれの場合も `get_project` で `type` が design-system であることを確認する

### Phase 3: ディレクトリ構成の作成
- `specs/screens` `specs/assets` `mocks` を既定値のまま作成する
- `mocks/_tokens.html` と `mocks/_layout.html` の雛形生成は確認を挟めないため行わない。実行フロー 3 が示す 2 択（雛形を作る / `design-mock` に任せる）のうち、非対話では `design-mock` に任せる側を既定として確定し、次のアクションとして案内する

### Phase 4: 設定ファイルの生成
- `.claude/design-bridge.json` を既定値（`specsDir: specs/screens`、`assetsDir: specs/assets`、`mocksDir: mocks`、`kind` 付きの既定 `watch`、`viewport: 1280x800`）で生成する
- **`blockLimit` を書かない。** ブロック挙動を変える値はリポジトリ設定から読まない設計のため、調整はユーザスコープ設定 `~/.claude/.local/plugins/design-bridge/user-config.json` で行う旨を案内する
- 既定構成で導入するため、`jq` 不在時のフックの縮退先（`specs` の `.md` / `mocks` の `.html`）と設定内容が一致することを報告に添える

### Phase 5: .gitignore の確認
- `.gitignore` に `.claude/.local/` が無ければ追記する（非対話のため確認を挟まない）

### Phase 6: venv の構築
- `bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.sh" --project-root "<プロジェクトルート>"` を実行する
- 非対話モードは既定値で確定して進行するため `--skip-browser` は付けず、Chromium まで導入する
- Chromium のダウンロード（展開後 約 690 MB）が発生することを実行前に伝える

### Phase 7: 導入完了の報告
- 既定値で確定した項目一覧
- `jq` 不在により、既定以外の `watch` 設定を書いても効かないこと（既定構成のままなら支障が無いこと）
- venv の場所（`.claude/.local/plugins/design-bridge/.venv`）と Chromium 導入済みである旨
- フックが有効になるには Claude Code の再起動が必要であること
- 次のアクション（`design-mock` / `design-push`）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `.claude/design-bridge.json`、`specs/screens/`、`specs/assets/`、`mocks/`、`.gitignore` への追記、`.claude/.local/plugins/design-bridge/.venv` |
| 設定ファイルの内容 | 既定値のみ。`blockLimit` を含まない。`watch` の 2 エントリに `kind` がある |
| 標準出力（要約） | 既定値で確定した構成一覧、紐付けた Claude Design プロジェクト名と ID、`jq` 不在で既定以外の `watch` 設定が効かない旨の警告、venv の場所と Chromium 導入済みである旨、次のアクション |
| 終了状態 | 成功（警告あり） |

## 禁止事項（このケースで起きてはならないこと）

- 非対話モードで `AskUserQuestion` を発火させること
- `jq` 不在を理由に導入を中断すること（任意依存であり、既定の監視対象へ縮退して動作する）
- `jq` 不在を「フックが動作しない」と誤って説明すること
- `jq` 不在を黙って無視し、警告なしで完了報告すること
- `get_project` の型確認を省略すること（非対話でも必須）
- `blockLimit` などブロック挙動を変える値を `.claude/design-bridge.json` に書くこと
- `watch` エントリから `kind` を省くこと
- venv の構築を他プラグインへ委譲すること、または `.claude/.local/plugins/design-bridge/.venv` 以外へ作ること

## 分岐の根拠

このケースが分岐するトリガーは「実行モード判定 = 非対話（`--non-interactive` フラグあり、または引数で projectId まで指定）」である。実行モード判定表の非対話行に従い、確認を挟まず既定値で確定して進行する。

あわせて実行フロー 1 の「`jq` の有無」検査が NG となる経路を扱う。前提セクションは `jq` を任意依存と定め、不在時は「既定以外の `watch` 設定が効かない」旨を伝えたうえで導入を続行してよいとしている。認可エラー（case-04）が中断に至るのと対照的に、ここは警告付きで完了する分岐である。

## 関連ケース

- [case-01](case-01_new_setup_interactive.md): 同じ新規導入の対話版（確認を挟む点と、Chromium を後回しにする点が異なる）
- [case-03](case-03_existing_config_update.md): 設定ファイルが既にある場合（非対話でも無確認上書きはしない）
- [case-04](case-04_design_auth_error.md): 前提不足でも中断に至る経路（認可エラー）
