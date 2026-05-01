# Case 25: SessionStart hook — 環境変数欠如時の silent exit

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | Claude Code セッション開始 |
| 既存状態 | `CLAUDE_PLUGIN_ROOT` または `HOME` が未設定（リモート環境・コンテナ等） |
| フラグ | なし |

## 期待動作

### Phase 1: 環境変数確認

- `install_rule_template.sh` 冒頭で `[[ -z "$PLUGIN_ROOT" ]]` を判定
- 真ならば即座に `exit 0`

### Phase 2: テンプレート不在の場合

- `$PLUGIN_ROOT/references/templates/rules/security/credentials-management.md` が存在しない場合も `exit 0`

### Phase 3: スコープ判定不能の場合

- user 分岐にも project 分岐にも該当しない場合 `exit 0`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 空 |
| 終了コード | 0 |
| 副作用 | なし（ファイル作成・通知出力なし） |

## 分岐の根拠

エラー系・境界条件の必須カバレッジ。リモート環境 / devcontainer / 制限環境で hook がエラーを吐かず、Claude Code セッション全体を阻害しない（fail-open）保証。

## 関連ケース

- `case-14_session_start_user_scope.md`
- `case-15_session_start_project_scope.md`
