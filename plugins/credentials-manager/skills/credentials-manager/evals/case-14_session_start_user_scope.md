# Case 14: SessionStart hook — user スコープでテンプレート初回配置

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | Claude Code セッション開始（user インストールスコープ） |
| 既存状態 | `~/.claude/rules/security/credentials-management.md` 未存在、`CLAUDE_PLUGIN_ROOT` が `~/.claude/plugins/cache/...` 配下、`HOME` 解決可能 |
| フラグ | なし |

## 期待動作

### Phase 1: スコープ判定

- `install_rule_template.sh` 内でパス正規化後、`$CLAUDE_PLUGIN_ROOT` が `$HOME/.claude/` 配下 → user スコープ
- 配置先 `TARGET_DIR` を `$HOME/.claude/rules/security` に確定

### Phase 2: テンプレート配置

- `$CLAUDE_PLUGIN_ROOT/references/templates/rules/security/credentials-management.md` を `$TARGET_DIR/credentials-management.md` にコピー
- 親ディレクトリ不在なら作成

### Phase 3: Claude へ通知

- `hookSpecificOutput.additionalContext` で「user スコープ向けに最重要ルールを新規配置しました」と通知
- `hookEventName: SessionStart`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `~/.claude/rules/security/credentials-management.md`（プラグイン同梱テンプレートと同一内容） |
| stdout | 有効な JSON（`continue: true`、`hookSpecificOutput.additionalContext` 含む） |
| 終了コード | 0 |

## 分岐の根拠

スコープ判定で user に分岐するケース（`$PLUGIN_ROOT_NORM == $HOME_DIR_NORM/.claude/*`）。

## 関連ケース

- `case-15_session_start_project_scope.md`（project スコープ分岐）
- `case-16_session_start_idempotent.md`（既存ファイル時の no-op）
- `case-25_session_start_missing_env_silent_exit.md`（環境変数欠如時）
