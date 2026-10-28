# Case 05: 候補が 0 件（create_project で新規作成）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「このリポジトリで画面モックを管理したい」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | git リポジトリ。Python 3.9 以上が利用可。`jq` 利用可。`/design-login` 認可済み。`.claude/design-bridge.json` なし。`list_projects` は成功するが、**書き込み可能な design-system プロジェクトが 0 件** |

## 期待動作

### Phase 1: 前提チェック
- プロジェクトルート・Python 3.9 以上・`jq` を確認する
- `.claude/design-bridge.json` が無いため新規導入として扱う

### Phase 2: Claude Design プロジェクトの決定
- `list_projects` は認可エラーではなく、候補 0 件の結果を返す（認可は通っている）
- 候補が 0 件であることをユーザに伝え、新規作成するかを確認する
- 承認された場合、プロジェクト名をユーザに確認したうえで `create_project` で design-system プロジェクトを作成する
- 作成結果の UUID を `projectId` として採用し、`get_project` で `type` が design-system であることを確認する
- 拒否された場合は紐付け先が確定しないため、`.claude/design-bridge.json` を作らずに中断する

### Phase 3: ディレクトリ構成の作成
- `specs/screens` `specs/assets` `mocks` を作成する
- `mocks/_tokens.html` と `mocks/_layout.html` が未作成のため、雛形を作るか `design-mock` に任せるかを確認する

### Phase 4: 設定ファイルの生成
- 作成したプロジェクトの UUID と表示名で `.claude/design-bridge.json` を生成する
- `watch` の各エントリに `kind` を明示し、ブロック挙動を変える値は書かない

### Phase 5: .gitignore の確認
- `.claude/.local/` の記載を確認し、無ければ追記の可否を確認してから追記する

### Phase 6: venv の構築
- `bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.sh" --project-root "<プロジェクトルート>"` を実行する
- Chromium のダウンロード（展開後 約 690 MB）が初回に発生することを事前に伝える。後回しにする場合は `--skip-browser` を使い、後から `python -m playwright install chromium` を実行する案内を残す

### Phase 7: 導入完了の報告
- **新規作成した** design-system プロジェクト名と ID であることを明示する
- 作成したディレクトリ・設定ファイル、venv の場所と Chromium 導入の有無、フック有効化に Claude Code の再起動が必要であること、次のアクションを提示する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `.claude/design-bridge.json`、`specs/screens/`、`specs/assets/`、`mocks/`、`.claude/.local/plugins/design-bridge/.venv`（いずれも新規作成を承認した場合） |
| リモート側の変化 | design-system 型のプロジェクトが 1 件新規作成される |
| 標準出力（要約） | 既存候補が 0 件であった旨、新規作成したプロジェクト名と ID、作成物、venv の場所と Chromium 導入の有無、次のアクション |
| 終了状態 | 成功（新規作成を拒否された場合は未導入のまま中断） |

## 禁止事項（このケースで起きてはならないこと）

- 確認なしに `create_project` を呼ぶこと
- design-system 以外の型でプロジェクトを作成すること（型は作成時に固定され後から変更できない）
- 候補 0 件を認可エラー（case-04）と取り違えて `/design-login` を促すこと
- 新規作成を拒否されたにもかかわらず、`projectId` を空のまま `.claude/design-bridge.json` を生成すること
- 作成直後の `get_project` による型確認を省略すること

## 分岐の根拠

このケースが分岐するトリガーは「実行フロー 2 の `list_projects` 結果 = 候補が 0 件」である。SKILL.md の表は候補 0 件の行で「新規作成するか確認し、`create_project` でプロジェクト名を指定して作成」と定めており、候補 1 件（確認のみ）・候補複数（選択）とは別経路になる。

`list_projects` の呼び出しが成功している点が case-04 との決定的な違いである。認可は通っているため中断せず、作成の可否確認だけで先に進める。

## 関連ケース

- [case-01](case-01_new_setup_interactive.md): 候補が複数あり選択に進むケース（「新規作成」も選択肢に含まれる）
- [case-04](case-04_design_auth_error.md): `list_projects` 自体が認可エラーで中断するケース
- [case-06](case-06_non_design_system_type.md): 候補はあるが型が design-system でなく、選び直しや新規作成に至るケース
