# Case 01: 未導入リポジトリへの新規導入（対話モード・候補複数）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「このリポジトリに design-bridge を導入して」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | git リポジトリ。Python 3.9 以上が利用可。`jq` 利用可。`/design-login` 認可済み。`.claude/design-bridge.json` なし。`specs/` `mocks/` なし。`.gitignore` に `.claude/.local/` の記載なし。書き込み可能な design-system プロジェクトが 2 件以上ある |

## 期待動作

### Phase 1: 前提チェック
- `.git` のあるディレクトリをプロジェクトルートとして特定する
- Python 3.9 以上が利用可能であることを確認する
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
- `watch` の各エントリに `kind` を明示する（`{ "dir": "specs", "ext": "md", "kind": "spec" }` と `{ "dir": "mocks", "ext": "html", "kind": "mock" }`）
- ブロックの強さ（連続通知の上限）はこのファイルに書かない。調整が必要な場合はユーザスコープ設定 `~/.claude/.local/plugins/design-bridge/user-config.json` で行う旨を案内する

### Phase 5: .gitignore の確認
- `.claude/.local/` の記載が無いことを検出し、追記の可否をユーザに確認したうえで追記する

### Phase 6: venv の構築
- プラグイン同梱スクリプトで venv を構築する

  ```bash
  bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.sh" \
    --project-root "<プロジェクトルート>"
  ```

- venv の作成先が `.claude/.local/plugins/design-bridge/.venv`（永続）であることを伝える
- Chromium のダウンロード（数百 MB）が初回に発生するため、所要時間を実行前にユーザへ伝える
- 本ケースではユーザが「後で入れる」を選んだため、`--skip-browser` を付けて Python 依存のみを導入し、後から `python -m playwright install chromium` を実行する案内を報告に残す

### Phase 7: 導入完了の報告
- 作成したディレクトリ・設定ファイル
- 紐付けた Claude Design プロジェクト名と ID
- venv の場所（`.claude/.local/plugins/design-bridge/.venv`）と Chromium 導入の有無（本ケースでは未導入）
- フックが有効になる条件（Claude Code の再起動が必要）
- 次のアクション（`design-mock` でモック生成、`design-push` で反映）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `.claude/design-bridge.json`、`specs/screens/`、`specs/assets/`、`mocks/`、`.claude/.local/plugins/design-bridge/.venv`（`.gitignore` は承認時に追記） |
| 設定ファイルの内容 | `projectId` / `projectName` / `specsDir` / `assetsDir` / `mocksDir` / `watch`（`kind` 付き 2 件） / `viewport`。これ以外の挙動を変える値を含まない |
| 標準出力（要約） | 作成したディレクトリと設定ファイル、紐付けた Claude Design プロジェクト名と ID、venv の場所と Chromium 未導入である旨および後追い手順、フック有効化には Claude Code の再起動が必要である旨、次のアクション（`design-mock` / `design-push`） |
| 終了状態 | 成功（Chromium は後追い） |

## 禁止事項（このケースで起きてはならないこと）

- 候補が複数あるのに確認せず 1 件目を選ぶこと
- `get_project` の型確認を省略し、design-system 型でないプロジェクトを `projectId` に設定すること
- `.gitignore` を無確認で書き換えること
- 既存の `specs/` `mocks/` の中身を書き換えること（このケースでは不在だが、作成以外の操作をしない）
- venv の構築を他プラグイン（`environment-setup-toolkit` 等）へ委譲すること。design-bridge 同梱の `setup_venv.sh` を使う
- venv をセッション作業領域（`workspace/.venv`）に作ること。作成先は `.claude/.local/plugins/design-bridge/.venv` に固定する
- `blockLimit` などブロック挙動を変える値を `.claude/design-bridge.json` に書くこと
- 数百 MB のダウンロードが発生することを伝えずに Chromium 取得を開始すること

## 分岐の根拠

このケースが分岐するトリガーは「実行モード判定 = 対話（フラグ・projectId 指定なし）」かつ「実行フロー 2 の `list_projects` 結果 = 候補が複数」である。

同じ Phase 2 の兄弟分岐として、候補が 1 件なら `AskUserQuestion` で「そのプロジェクトで良いか」の確認のみになる。以降の Phase 3 以降は本ケースと同一である。

Phase 6 の兄弟分岐として、Chromium の所要時間を伝えたうえでユーザが即時構築を選んだ場合は `--skip-browser` を付けずに `setup_venv.sh` を実行し、同じ実行で Chromium まで導入する。この場合の報告は「Chromium 導入済み」に変わり、後追い手順の案内は不要になる。

## 関連ケース

- [case-02](case-02_new_setup_non_interactive.md): 同じ新規導入を確認なしで進める非対話版（`jq` 不在の経路も扱う）
- [case-03](case-03_existing_config_update.md): `.claude/design-bridge.json` が既にある場合（Phase 1 で更新モードへ分岐）
- [case-04](case-04_design_auth_error.md): Phase 2 の `list_projects` が認可エラーを返す場合
- [case-05](case-05_no_candidate_create_project.md): Phase 2 の候補が 0 件で `create_project` に進む場合
- [case-06](case-06_non_design_system_type.md): Phase 2 の `get_project` で design-system 型でないと判明する場合
