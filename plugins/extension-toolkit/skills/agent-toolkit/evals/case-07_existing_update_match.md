# Case 07: 既存エージェント改修（専門性一致時の正常系）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`implementation-engineer` エージェントに SOLID 原則の評価観点を追加" |
| 引数 | `implementation-engineer --add-criteria "SOLID principles"` |
| フラグ | なし |
| 既存状態 | `implementation-engineer.md` 既存 |

## 期待動作

### Phase 1: 既存定義読込

`~/.claude/agents/implementation-engineer.md` を Read。

### Phase 2: 適合性判定（専門領域一致）

SOLID 原則はコード設計の評価観点であり、`implementation-engineer` の専門領域（コード品質 / 正確性 / パフォーマンス / 可読性）と完全に一致。
**専門性警告は表示せず**、追加観点として処理。

### Phase 3: 評価観点の追加

既存の評価観点セクションに SOLID 原則の各原則（SRP / OCP / LSP / ISP / DIP）を追加:

- 単一責任原則（SRP）: 各クラス・関数が単一の責務を持つか
- 開放閉鎖原則（OCP）: 拡張に対して開かれ修正に対して閉じているか
- リスコフ置換原則（LSP）: サブタイプは基底タイプと置換可能か
- インターフェース分離原則（ISP）: 不要なインターフェース実装を強制していないか
- 依存性逆転原則（DIP）: 抽象に依存し具象に依存していないか

### Phase 4: 検証 + 引き渡し

| 確認項目 | 動作 |
|---------|------|
| エンコーディング維持 | バイト列比較で確認 |
| 専門性の相補性 | 既存観点との重複なしを確認 |
| 評価観点 3 つ以上 | 追加後も維持を確認 |
| frontmatter `name` 一致 | 変更なしを確認 |

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `~/.claude/agents/implementation-engineer.md`（評価観点セクション拡張） |
| 標準出力 | 「`implementation-engineer` エージェント改修完了（SOLID 原則を追加）」+ 差分プレビュー |
| 終了状態 | 成功 |
| ユーザ対話 | 専門性警告なし、観点の追加可否のみ簡潔に確認 |

## 分岐の根拠

同名エージェント既存 + 専門領域 **一致** の検出 → 警告フローをスキップして直接追加。
case-03 が「専門領域不一致」の警告フロー、本ケースが「一致」の正常フロー、両者が同値分割の対称ペア。

## 関連ケース

- `case-01_single_agent.md`（新規作成）
- `case-03_existing_update.md`（専門領域不一致、警告フロー）
- `case-06_non_interactive.md`（非対話モード）
