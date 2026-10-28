# Case 03: 導入済みリポジトリでの再実行（更新モード）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「design-bridge の紐付けを別のプロジェクトに変えたい」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | git リポジトリ。Python 3.9 以上が利用可。`jq` 利用可。`/design-login` 認可済み。`.claude/design-bridge.json` が既に存在する（`watch` に `kind` が無い旧形式）。`specs/screens` に設計書が、`mocks/` にモック HTML が既にある。`.claude/.local/plugins/design-bridge/.venv` が構築済み |

## 期待動作

### Phase 1: 前提チェック
- `.claude/design-bridge.json` の存在を検出し、**更新モード** として扱う
- 既存設定の内容を読み取る
- Python 3.9 以上と `jq` の確認は新規導入と同様に行う

### Phase 2: Claude Design プロジェクトの決定
- `list_projects` で候補を一覧し、現在の紐付け先を明示したうえで変更先を確認する
- 選択後、`get_project` で `type` が design-system であることを確認する

### Phase 3: ディレクトリ構成の作成
- `specsDir` `assetsDir` `mocksDir` が既に存在するため、それを流用し作り直さない
- 既存の設計書・モック HTML には一切触れない
- `mocks/_tokens.html` と `mocks/_layout.html` が既にある場合は確認を行わない

### Phase 4: 設定ファイルの生成
- 新旧の差分（変更されるフィールドと値）を提示する
- 旧設定の `watch` に `kind` が無いため、`kind`（`spec` / `mock`）を補う案を差分として併せて提示する。`kind` は Stop フックの誘導先（モックは `bridge-push`、設計書は `bridge-mock`）を決めるため明示を推奨する
- 旧設定に `blockLimit` などブロック挙動を変える値が残っていた場合は、新しい設定へ引き継がず除去する案を提示し、調整はユーザスコープ設定 `~/.claude/.local/plugins/design-bridge/user-config.json` で行う旨を案内する
- 上書きの可否をユーザに確認し、承認された場合のみ書き込む

### Phase 5: .gitignore の確認
- `.gitignore` の `.claude/.local/` 登録を再確認する（登録済みなら何もしない）

### Phase 6: venv の確認
- `.claude/.local/plugins/design-bridge/.venv` が既にあるため再構築しない
- 再実行が必要な場合でも `setup_venv.sh` は既存 venv を再利用する（作り直さない）ことを前提に判断する

### Phase 7: 報告
- 更新したフィールドと、据え置いたフィールドを区別して提示する
- venv は既存を再利用した旨を併記する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `.claude/design-bridge.json`（承認時のみ更新）。既存の `specs/` `mocks/` 配下と `.venv` は無変更 |
| 設定ファイルの内容 | 更新後も `blockLimit` などブロック挙動を変える値を含まない。`watch` の各エントリに `kind` がある |
| 標準出力（要約） | 更新モードである旨、新旧差分（`projectId` の変更、`kind` の補完、挙動を変える値の除去）、更新したフィールド一覧、据え置いたフィールド、venv 再利用、次のアクション |
| 終了状態 | 成功（ユーザが上書きを拒否した場合は変更なしで終了） |

## 禁止事項（このケースで起きてはならないこと）

- `.claude/design-bridge.json` を差分提示・確認なしで上書きすること
- 既存の `specs/` `mocks/` の中身を書き換えること
- 既存ディレクトリを削除して作り直すこと
- 既存 venv を削除して作り直すこと（Chromium の再ダウンロードが無駄に発生する）
- 旧設定に書かれていた `blockLimit` などの値を、そのまま新しい設定へ引き継ぐこと

## 分岐の根拠

このケースが分岐するトリガーは「実行フロー 1 の検査結果 = `.claude/design-bridge.json` が既に存在する」である。この場合は新規導入ではなく更新モードとなり、上書き前の差分提示が必須になる（重要な制約「`.claude/design-bridge.json` を無確認で上書きしない」）。

旧形式の設定を扱う点も本ケースの検証対象である。`watch` の `kind` は後から追加されたキーであり、`blockLimit` はリポジトリ設定から読まない方針へ変わった値であるため、更新モードはこの 2 点を差分として扱う必要がある。

## 関連ケース

- [case-01](case-01_new_setup_interactive.md): 設定ファイルが無い新規導入（差分提示が発生しない）
- [case-02](case-02_new_setup_non_interactive.md): 非対話モード（ただし設定ファイルの無確認上書きはこのケースでも禁止）
- [case-06](case-06_non_design_system_type.md): 変更先として選んだプロジェクトが design-system 型でなかった場合
