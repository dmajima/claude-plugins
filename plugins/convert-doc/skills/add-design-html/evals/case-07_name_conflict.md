# Case 07: 予約名の拒否

## 入力

- ユーザーが予約名をデザイン名に指定（「template という名前で」「default という名前で」）

## 期待動作

1. `template` / `default` は予約名のため使用できないことを伝える
2. 別名（kebab-case）の提示を求め、確定するまで生成に進まない

## 期待出力

- 予約名のデザインファイル（`template.css` の上書きや `default.*`）が作られない

## 分岐の根拠

`references/design-locations.md` 節 5「命名規則」:
> 予約名（使用禁止）: `template`（デフォルト CSS / HTML の名前）、`default`（PPTX 内蔵デフォルトの表示名）

## 関連ケース

- [case-11_existing_name_conflict.md](case-11_existing_name_conflict.md): 既存デザイン名との重複（動的検出）
- [case-01_interactive_css_only.md](case-01_interactive_css_only.md): 衝突がない通常フロー
