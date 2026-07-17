# case-01 DB 変更あり（architect + dba 並列起動）

レビュー対象の差分にマイグレーション SQL / DB スキーマ変更が含まれるケース。DB 変更判定により dba を起動し、architect と 1 メッセージ内で並列起動することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `<差分スコープ（マイグレーション SQL / スキーマ変更を含む）> <プロジェクト規約サマリ> mode=standard` |
| 起動形態 | 委譲（code-review オーケストレーターから Skill ツール経由・標準モード） |
| 前提 | DB 情報（DB 種別・テーブル規模・想定データ量等）が引数で渡されている |

## 分岐の根拠

SKILL.md「実行フロー」手順 2「DB 変更があるか判定し、`dba` の起動可否を決定」および手順 3 のコード例（dba は「DB 変更あり時のみ」並列起動）、SKILL.md「動的に省略可（責務はオーケストレーター）」の表（architect: 常に起動 / dba: SQL・DB スキーマ・マイグレーション変更が一切ない場合のみ内部で省略）、SKILL.md「出力フォーマット」の「### dba（DB変更あり時のみ）」、references/checklist.md セクション B O1（該当エージェント（architect, DB変更ある場合のみ dba）を 1 メッセージ内で並列起動）およびセクション C C-Auto-2（DB 変更がある場合は dba セクションが存在しているか）。

## 期待動作

- 差分に SQL / DB スキーマ / マイグレーション変更が含まれることを判定し、dba の起動を決定する（SKILL.md「実行フロー」手順 2）
- architect / dba の 2 エージェントを 1 メッセージ内で並列起動する（references/checklist.md O1）
- 中間レポートに「### architect」「### dba（DB変更あり時のみ）」の両セクションを含める（SKILL.md「出力フォーマット」/ checklist.md C-Auto-1 / C-Auto-2）
- dba はスキーマ変更の安全性評価・マイグレーション戦略・インデックス / クエリ最適化提案を報告する（SKILL.md「出力フォーマット」）
- architect は設計上の問題・技術的負債リスク・コンポーネント境界 / 依存方向の指摘を報告する（SKILL.md「出力フォーマット」）
- 実装一般・テスト・セキュリティ・UI 観点はスコープ外として対応スキルへ誘導する（checklist.md O4）
- Finding ID（CR-NNN）の採番・Verdict 判定は行わない（checklist.md O9 / SKILL.md「重要な制約」）

## 関連ケース

- case-02: DB 変更なし（dba を内部省略）
