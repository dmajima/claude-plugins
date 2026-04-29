# Case 03: 既存スキル改修

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`code-formatter` スキルに `--check-only` モードを追加" |
| 引数 | `code-formatter`（既存スキル名）+ 改修内容の自然言語 |
| フラグ | なし |
| 既存状態 | `code-formatter/SKILL.md` あり |

## 期待動作

### Phase 1: 改修対象特定

`code-formatter` スキルの所在を Glob で確認。複数候補があれば対話で選択。

### Phase 2: 差分内容の整理

| 改修種別 | 動作 |
|---------|------|
| 機能追加 | `references/check-only-mode.md` 作成、`SKILL.md` の実行フローに条件分岐追加 |

### Phase 3: SKILL.md 200 行制約の維持

改修後の行数を確認、超過時は references に分離。

### Phase 4: evals 同期

`--check-only` フラグの動作分岐に対応する evals ケースを追加。

### Phase 5: 検証 + 引き渡し

検証チェックリスト合格を確認、変更ファイル一覧を提示。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `code-formatter/SKILL.md`（追記）+ `references/check-only-mode.md`（新規）+ `evals/case-XX_check_only.md`（新規） |
| 標準出力（要約） | 「`code-formatter` スキルに `--check-only` モードを追加しました」+ 変更箇所サマリ |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーはスキル名 = 既存スキル かつ ユーザが「追加」「変更」「更新」と発話 である。

## 関連ケース

- `case-01_new_skill_interactive.md`（新規作成）
