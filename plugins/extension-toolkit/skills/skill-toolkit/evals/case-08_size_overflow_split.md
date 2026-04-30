# Case 08: 既存改修で SKILL.md が 200 行超過 → references 分離

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`code-formatter` スキルに新しい評価観点を追加" |
| 引数 | `code-formatter --add-criteria "SOLID / Clean Code / 命名規則 / テスト容易性 / パフォーマンス計測"` |
| フラグ | なし |
| 既存状態 | `skills/code-formatter/SKILL.md` が 190 行（200 行制約に余裕 10 行）|

## 期待動作

### Phase 1: 既存解析 + 改修計画

| 項目 | 値 |
|-----|---|
| 現在行数 | 190 行 |
| 追加予定行数 | 約 30 行（評価観点 5 項目分の追記） |
| 改修後の予測行数 | 約 220 行 |

200 行制約超過を **事前に予測**。

### Phase 2: ユーザに分離方針を確認

`AskUserQuestion` で以下を提示:

```text
SKILL.md 改修後に 200 行制約（conventions.md 節 3.5）を超過する見込みです（予測 220 行）。

以下のいずれかで対応しますか？

1. 詳細セクションを `references/{trait}.md` に分離（推奨、SSOT 集約）
2. SKILL.md を簡潔化してから追加（既存記述を圧縮）
3. キャンセル
```

### Phase 3: 選択分岐

| 選択 | 動作 |
|-----|------|
| 1 | 評価観点詳細を `skills/code-formatter/references/criteria.md` に分離、SKILL.md 本文には「詳細は references/criteria.md」のみ記載（生成された SKILL.md では Markdown リンク表記）|
| 2 | 既存セクションの圧縮箇所をユーザに提示、合意後に圧縮 + 追記 |
| 3 | 何もせず終了 |

### Phase 4: 検証 + 引き渡し

選択 1 / 2 後、改修後 SKILL.md の行数を再計測:

| 項目 | 動作 |
|-----|------|
| 改修後 SKILL.md 行数 | 200 行以下を確認 |
| 必須セクション維持 | 8 セクション全存続を確認 |
| references リンクの整合 | 新規ファイルへのリンクが解決可能 |
| 過去履歴の混入なし | ADR-016 整合 |

```text
code-formatter スキルの改修が完了しました（200 行制約遵守）。

変更内容:
- SKILL.md: 190 行 → 198 行（+ 評価観点サマリ 8 行）
- references/criteria.md: 新規作成（SOLID / Clean Code / 命名規則 / テスト容易性 / パフォーマンス計測 詳細）
```

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `skills/code-formatter/SKILL.md`（簡潔化追記）+ `skills/code-formatter/references/criteria.md`（新規詳細）|
| 標準出力 | 200 行制約予測警告 → 選択肢 → 選択結果 → 行数確認 |
| 終了状態 | 200 行以下で完了 / キャンセル |

## 分岐の根拠

既存 SKILL.md が 190 行 + 改修で 30 行追加 → 200 行超過予測 → references 分離フローに分岐。
[`../../../references/conventions.md`](../../../references/conventions.md) 節 3.5 の 200 行制約と [`../../../references/readme-policy.md`](../../../references/readme-policy.md) の SSOT 原則を満たす。

## 関連ケース

- `case-03_existing_skill_update.md`（既存改修、200 行内に収まる場合）
- `case-01_new_skill_interactive.md`（新規作成、最初から分離設計）
