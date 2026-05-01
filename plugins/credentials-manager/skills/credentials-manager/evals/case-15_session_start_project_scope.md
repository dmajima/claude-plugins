# Case 15: SessionStart hook — project スコープでテンプレート初回配置

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | Claude Code セッション開始（project / local インストールスコープ） |
| 既存状態 | `<project>/.claude/rules/security/credentials-management.md` 未存在、`CLAUDE_PLUGIN_ROOT` が `<project>/.claude/plugins/cache/...` 配下、`CLAUDE_PROJECT_DIR` 解決可能 |
| フラグ | なし |

## 期待動作

### Phase 1: スコープ判定

- `$CLAUDE_PLUGIN_ROOT` が `$HOME/.claude/` 配下でない → user 分岐に該当しない
- `$CLAUDE_PROJECT_DIR` あり → project スコープ
- 配置先 `TARGET_DIR` を `$CLAUDE_PROJECT_DIR/.claude/rules/security` に確定

### Phase 2: テンプレート配置

- `$CLAUDE_PLUGIN_ROOT/references/templates/rules/security/credentials-management.md` を `$TARGET_DIR/credentials-management.md` にコピー

### Phase 3: Claude へ通知

- `additionalContext` で「project スコープ向けに最重要ルールを新規配置しました」と通知

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `<project>/.claude/rules/security/credentials-management.md` |
| stdout | 有効な JSON（project スコープ通知文を含む） |
| 終了コード | 0 |

## 分岐の根拠

スコープ判定で project に分岐するケース。local スコープも同じ分岐で配置先が一致する。

## 関連ケース

- `case-14_session_start_user_scope.md`
- `case-16_session_start_idempotent.md`
