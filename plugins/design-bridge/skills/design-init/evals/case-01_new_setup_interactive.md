# Case 01: 未導入リポジトリへの新規導入（対話モード・候補複数）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「このリポジトリに design-bridge を導入して」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | git リポジトリ。`jq` 利用可。`/design-login` 認可済み。`.claude/design-bridge.json` なし。`specs/` `mocks/` なし。`.gitignore` に `.claude/.local/` の記載なし。書き込み可能な design-system プロジェクトが 2 件以上ある |

## 期待動作

### Phase 1: 前提チェック
- `.git` のあるディレクトリをプロジェクトルートとして特定する
- `jq` が利用可能であることを確認する
- `.claude/design-bridge.json` が存在しないため、新規導入として扱う

### Phase 2: Claude Design プロジェクトの決定
- `DesignSync` の `list_projects` で書き込み可能な design-system プロジェクトを一覧する
- 候補が複数のため `AskUserQuestion` で選択させる。選択肢には「新規作成」も含める
- 選択後、`get_project` で `type` が design-system であることを確認する

### Phase 3: ディレクトリ構成の作成
- `specs/screens` `specs/assets` `mocks` を作成する
- `mocks/_tokens.html` と `mocks/_layout.html` が未作成のため、雛形を作るか `design-mock` に任せるかをユーザに確認する

### Phase 4: 設定ファイルの生成
- `.claude/design-bridge.json` を `references/config-schema.md` の形式で生成する
- `projectId` には選択した design-system プロジェクトの UUID を設定する

### Phase 5: .gitignore の確認
- `.claude/.local/` の記載が無いことを検出し、追記の可否をユーザに確認したうえで追記する

### Phase 6: venv の構築
- `environment-setup-toolkit` に委譲して venv を構築する（依存定義は `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/requirements.txt`）
- `playwright install chromium` によるブラウザバイナリ取得が別途必要である旨を伝える

### Phase 7: 導入完了の報告
- 作成物・紐付け先・フック有効化条件・次のアクションを提示する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `.claude/design-bridge.json`、`specs/screens/`、`specs/assets/`、`mocks/`（`.gitignore` は承認時に追記） |
| 標準出力（要約） | 作成したディレクトリと設定ファイル、紐付けた Claude Design プロジェクト名と ID、フック有効化には Claude Code の再起動が必要である旨、次のアクション（`design-mock` / `design-push`） |
| 終了状態 | 成功 |

## 禁止事項（このケースで起きてはならないこと）

- 候補が複数あるのに確認せず 1 件目を選ぶこと
- `get_project` の型確認を省略し、design-system 型でないプロジェクトを `projectId` に設定すること
- `.gitignore` を無確認で書き換えること
- 既存の `specs/` `mocks/` の中身を書き換えること（このケースでは不在だが、作成以外の操作をしない）

## 分岐の根拠

このケースが分岐するトリガーは「実行モード判定 = 対話（フラグ・projectId 指定なし）」かつ「実行フロー 2 の `list_projects` 結果 = 候補が複数」である。

同じ Phase 2 の兄弟分岐として、候補が 1 件なら `AskUserQuestion` で「そのプロジェクトで良いか」の確認のみになり、候補が 0 件なら新規作成の可否を確認して `create_project` でプロジェクト名を指定して作成する。いずれも確認の形が変わるだけで、以降の Phase 3 以降は本ケースと同一である。また `get_project` の結果が design-system 型でなかった場合は、そのプロジェクトを `projectId` に設定せず、別プロジェクトの選択または新規作成に戻る（型は作成時に固定され後から変更できないため）。

## 関連ケース

- [case-02](case-02_new_setup_non_interactive.md): 同じ新規導入を確認なしで進める非対話版
- [case-03](case-03_existing_config_update.md): `.claude/design-bridge.json` が既にある場合（Phase 1 で更新モードへ分岐）
- [case-04](case-04_design_auth_error.md): Phase 2 の `list_projects` が認可エラーを返す場合
