# case-20 C8 スコープ外指摘の専用セクション分離（判断理由付き格納と連番採番の整合・正常系）

観点別スキルから**スコープ外フラグ付き finding** を受領したオーケストレーターが、これを「## 3. スコープ外指摘」セクションへ**判断理由付き**で格納し、Issues → Suggestions → Scope-out の Finding ID 連番採番（C14）が整合する**肯定的な正常系**を検証する。case-16 が「スコープ外へ誤分類しない」という否定形でのみスコープ外に触れるのに対し、本ケースは正当なスコープ外分離の成立側を見る。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "このブランチをレビューして"（PR / ブランチの目的は「注文確定機能の追加」。差分は新規追加ファイル中心） |
| モード | 標準 |
| 観点別スキルからの返却（想定） | Issues 相当 3 件（例: Critical/High/Medium）+ Suggestions 相当 2 件に加え、code-review-architecture が「既存 OrderService 全体の Repository パターン移行」を **スコープ外フラグ付き**（PR 差分が触れていない既存実装の課題・PdM 判断が必要）で返却する |

## 分岐の根拠

`${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` C8「スコープ外指摘の専用セクション（『## 3. スコープ外指摘』に分離し、判断理由を必須記載）」（SSOT: `${CLAUDE_PLUGIN_ROOT}/references/scope-out-policy.md` セクション 3「スコープ外指摘の必須記載項目」）、C5「結果統合・重複排除（Issues / Suggestions / Scope-out に三分類）」、C13「Finding ID の一括採番」・C14「Finding ID の連続通番（Issues → Suggestions → Scope-out の順）」、`${CLAUDE_SKILL_DIR}/references/output/output-format.md` セクション 2.3「スコープ外指摘の項目」。観点別スキルは O5 でスコープ内 / 外フラグを付与して返却し、分離・採番はオーケストレーターの責務である点が分岐の要点。

## 期待動作

- Step 5: 観点別スキルが返した**スコープ外フラグ付き finding**（既存 OrderService の Repository パターン移行）を、Issues（対応が必要な指摘）にも Suggestions（改善提案）にも混入させず、Scope-out に三分類する（C5 / C8）
- Step 8: 当該 finding を統合サマリの「## 3. スコープ外指摘」セクションに格納する（C8・output-format.md セクション 2.3）
- スコープ外指摘には scope-out-policy.md セクション 3 の必須項目を記載する: スコープ外と判断した理由（PR 目的「注文確定機能追加」の範囲外・既存実装の課題・PdM 判断が必要のいずれに該当するか）／該当箇所（`src/order/OrderService.cs` 等の参考情報）／提案カテゴリ（既存技術的負債）／該当コード（参考引用）／所見
- Step 6: Finding ID を一括採番する（C13）。採番順は Issues（致命度高い順）→ Suggestions（Impact×Effort 降順）→ Scope-out（重要度順）の記載順で、統合サマリ全体で連続通番（例: Issues=CR-001〜CR-003、Suggestions=CR-004〜CR-005、Scope-out=CR-006）となる（C14・output-format.md セクション 1.5）
- スコープ外指摘の本文に「別 PR で対応してください」「別途 PR を起票してください」「別チケット化してください」等の禁止文言を含めない（scope-out-policy.md セクション 3.2）。記載してよいのは「本 PR のスコープ外と判断したため対応を求めない」「将来検討に値する事項として記録する」等（同 3.1）
- 集計セクションにスコープ外件数（1 件）を反映する（output-format.md セクション 1.4）
- （以下は検出してはならない誤り）
    - スコープ外フラグ付き finding を Issues / Suggestions に混入させる（本 PR の修正対象を曖昧化）
    - 判断理由を明示せずにスコープ外へ分離する（読み手が判断根拠を追跡できない）
    - Scope-out を採番から除外し Finding ID の連番に欠番を生じさせる

## 関連ケース

- case-16: U16 回帰を「スコープ外へ誤分類しない」否定形での言及（本ケースの正常系分離と対になる）
- case-15: Finding ID 命名衝突時の採番（C13 / C14 の採番規則を扱う別分岐）
- case-14: プロファイルアンカー照合による Issues 再配置（同じ Step 5 三分類の重要度整合）
