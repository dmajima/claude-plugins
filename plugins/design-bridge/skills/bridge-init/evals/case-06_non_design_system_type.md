# Case 06: 選んだプロジェクトが design-system 型でない（選び直す）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「画面設計書と Claude Design を連動させたい」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | git リポジトリ。Python 3.9 以上が利用可。`jq` 利用可。`/design-login` 認可済み。`.claude/design-bridge.json` なし。候補一覧に複数のプロジェクトが並ぶが、**ユーザが最初に選んだものは `get_project` で design-system 型でないと判明する** |

## 期待動作

### Phase 1: 前提チェック
- プロジェクトルート・Python 3.9 以上・`jq` を確認し、新規導入として扱う

### Phase 2: Claude Design プロジェクトの決定
- `list_projects` の結果を `AskUserQuestion` で提示し、ユーザが 1 件選ぶ
- 選択後、`get_project` で `type` を確認する。**design-system 型でないことが判明する**
- そのプロジェクトを `projectId` に採用せず、理由を説明する
  - 通常プロジェクトへは push できない
  - 型は作成時に固定され、後から design-system へ変更できない
- 選び直しを促し、別の候補を選ばせる。選べる候補が残らなければ、実行フロー 2 の「候補が 0 件」と同じ状況（case-05）に帰着する
- 選び直した候補について再度 `get_project` を実行し、design-system 型であることを確認してから採用する

### Phase 3: ディレクトリ構成の作成
- 採用が確定した後に `specs/screens` `specs/assets` `mocks` を作成する
- `mocks/_tokens.html` と `mocks/_layout.html` が未作成のため、雛形を作るか `bridge-mock` に任せるかを確認する

### Phase 4: 設定ファイルの生成
- 確認が取れた design-system プロジェクトの UUID で `.claude/design-bridge.json` を生成する
- `watch` の各エントリに `kind` を明示し、ブロック挙動を変える値は書かない

### Phase 5: .gitignore の確認
- `.claude/.local/` の記載を確認し、無ければ追記の可否を確認してから追記する

### Phase 6: venv の構築
- `bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.sh" --project-root "<プロジェクトルート>"` を実行する
- Chromium のダウンロード（展開後 約 690 MB）が初回に発生することを事前に伝える。後回しにする場合は `--skip-browser` を使う

### Phase 7: 導入完了の報告
- 最終的に採用した design-system プロジェクト名と ID
- 型が合わず除外したプロジェクトと、その理由
- 作成物、venv の場所と Chromium 導入の有無、フック有効化に Claude Code の再起動が必要であること、次のアクション

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `.claude/design-bridge.json`（`projectId` は design-system 型が確認できたもの）、`specs/screens/`、`specs/assets/`、`mocks/`、`.claude/.local/plugins/design-bridge/.venv` |
| 標準出力（要約） | 最初に選んだプロジェクトが design-system 型でなかった旨と理由、選び直した結果、採用したプロジェクト名と ID、作成物、次のアクション |
| 終了状態 | 成功（選び直し後に完了。採用できる候補が無く新規作成も拒否された場合は未導入のまま中断） |

## 禁止事項（このケースで起きてはならないこと）

- design-system 型でないプロジェクトを `projectId` に設定すること
- `get_project` を省略し、`list_projects` の情報だけで採用を確定すること
- 型を design-system へ変更しようと試みること（作成時に固定され変更できない）
- 型が合わないまま先にディレクトリ構成・設定ファイル・venv を作ること
- 型不一致を理由にその場で中断し、選び直しや新規作成の機会を提示しないこと

## 分岐の根拠

このケースが分岐するトリガーは「実行フロー 2 の `get_project` の結果 = `type` が design-system でない」である。SKILL.md は「選択後、`get_project` で `type` が design-system であることを必ず確認する。通常プロジェクトへは push できない（型は作成時に固定され後から変更できない）。型が違う場合は選び直す」と定めており、重要な制約にも「`projectId` に design-system 型でないプロジェクトを設定しない」が挙げられている。

`list_projects` は書き込み可能な design-system プロジェクトを一覧する想定だが、採用の確定は `get_project` の型確認を経る必要がある。この二段構えが崩れると、push できないプロジェクトを紐付けた状態で導入が完了してしまう。

## 関連ケース

- [case-01](case-01_new_setup_interactive.md): 候補複数から選び、1 回の `get_project` で型確認が通る正常系
- [case-05](case-05_no_candidate_create_project.md): 採用できる候補が無く `create_project` に進むケース（本ケースの行き着く先にもなりうる）
- [case-03](case-03_existing_config_update.md): 更新モードで変更先を選ぶ場合も同じ型確認が必要になる
