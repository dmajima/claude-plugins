# Case 16: SessionStart hook — 既存ファイル時の no-op（idempotent）

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | Claude Code セッション開始（任意スコープ） |
| 既存状態 | 配置先（user / project いずれか）に `credentials-management.md` が **既に存在** |
| フラグ | なし |

## 期待動作

### Phase 1: スコープ判定

- スコープ判定に成功し、配置先 `TARGET` が決定する

### Phase 2: 既存ファイル検出

- `[[ -f "$TARGET" ]]` が真 → 直ちに `exit 0`
- ファイル上書きしない（ユーザー編集を尊重）
- `additionalContext` も出力しない（無音）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 既存ファイル | 内容が **変更されない** |
| stdout | 空 |
| 終了コード | 0 |

## 分岐の根拠

idempotency 担保の重要分岐。テンプレート更新時にユーザー編集を破壊しない仕様の根拠。
プラグイン更新でテンプレートを更新する場合、ユーザー側で旧ファイル削除 or 手動マージが必要となる運用前提を明示する。

## 関連ケース

- `case-14_session_start_user_scope.md`
- `case-15_session_start_project_scope.md`
