# Case 08: 非対話モード + チームサイズ不足のエラー終了

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "コードレビューチームを 2 名で編成（自動）" |
| 引数 | `--non-interactive --team code-review --members "implementation-engineer,test-engineer"` |
| フラグ | `--non-interactive` + `--team` |
| 既存状態 | 各メンバー既存、チーム未作成 |

## 期待動作

### Phase 1: モード判定 + メンバー数検証

`--non-interactive` 検出 → 非対話モード（対話確認なし）。
メンバー数 = 2 名 → レビュー系チームの最低 3 名要件（[`../references/team-design.md`](../references/team-design.md) 節「チームサイズ」）を満たさない。

### Phase 2: fail-closed エラー終了

非対話モードでは `AskUserQuestion` による警告 + 選択肢提示が成立しないため、即時エラー終了:

```text
[agent-toolkit] Error: Team size requirement not met (non-interactive mode).

Specified members: 2 (implementation-engineer, test-engineer)
Required: minimum 3 members for review-style teams
  (or 2 members if perspective is structurally fixed; not applicable here)

To proceed in non-interactive mode, specify at least one additional member:
  --members "implementation-engineer,test-engineer,security-engineer"

Or run in interactive mode for AskUserQuestion-based confirmation.
```

`exit 1` で終了。チーム定義ファイルは **作成しない**（中途半端な状態を作らない）。

### Phase 3: 引き渡し（処理停止）

| 項目 | 動作 |
|-----|------|
| チーム定義ファイル生成 | なし |
| `marketplace.json` 等の編集 | なし |
| 終了コード | 1 |

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | なし |
| 標準エラー出力 | チームサイズ要件エラー + 解決方法案内 |
| 終了状態 | 失敗（exit 1）|
| ユーザ対話 | 発生しない |

## 分岐の根拠

`--non-interactive` + メンバー 2 名 → 対話確認が成立しないため fail-closed。
case-05（対話モード + 2 名指定）は警告 + 選択肢を提示するが、本ケースは対話不可のため即時エラー終了する同値分割の対称ペア。

## 関連ケース

- `case-05_team_size_warning.md`（対話モード、警告 + 選択肢提示）
- `case-02_review_team.md`（対話モード、4 名で正常編成）
- `case-06_non_interactive.md`（非対話モード、単体エージェントの正常生成）
