# Case 16: XR-5 Unknown の出力解析境界値（既定パターンと微妙に異なる exit 0）

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all` |
| `mode` | `normal` |
| `target` | `all` |
| 既存状態 | claude plugin CLI が exit code 0 を返すが、出力フォーマットがロケール変化等で
  既定の正規表現にマッチしない（例: `Already up to date.` → `すでに最新です`）|

## 期待動作

### Phase A〜E: 通常通り実行
- 各 `claude plugin update <name>@<mp>` の exit code は 0
- 出力パターンマッチング:
  - 成功（パターンマッチ）と判定できないため Unknown 区分に分類

### Phase F: XR-5 閾値判定
- 試行 N 件中の Unknown 比率を計算
- 20% を超えていれば XR-5 警告を Phase F-1 のサマリに出力
- 20% 以下なら Unknown 件数のみ報告（警告なし）

### 境界値テスト

| 試行 | Unknown | Unknown 比率 | 期待 |
|-----|---------|-------------|------|
| 10  | 2       | 20%         | 警告なし（閾値以下） |
| 10  | 3       | 30%         | XR-5 警告発火 |
| 5   | 1       | 20%         | 警告なし |
| 5   | 2       | 40%         | XR-5 警告発火 |

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Unknown 比率 ≤ 20% | サマリに「Unknown: N 件」のみ |
| Unknown 比率 > 20% | XR-5 警告メッセージ（公式ドキュメント URL + 確認手順含む） |
| 終了状態 | exit 0（Unknown は Failed ではないため） |

## 分岐の根拠

このケースが分岐するトリガーは Unknown 区分の発生（exit code 0 + 出力パターン非マッチ）で、
XR-5 の閾値（20%）を境界とした分岐確認である。

`case-14_xr5_unknown_threshold.md` は閾値超過時の警告動作の主流ケースだが、本ケースは
**閾値ちょうど（20%）と超過初期（21%）の境界値** に焦点を当て、ロケール変化や微妙な
出力フォーマット差で発生する Unknown を回帰検出する設計。

## 設計意図

XR-5 は CLI フォーマット変更への感度を担保する装置。閾値境界での挙動を独立に固定することで、
将来 CLI ロケール対応・パターン追加時の off-by-one 回帰を防ぐ。

## 関連ケース

- `case-14_xr5_unknown_threshold.md`（30% 超の主流警告ケース）
- references/cross-cutting-rules.md XR-5 詳細仕様
