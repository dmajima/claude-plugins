---
description: convert-html / convert-pdf 用の新しいデザイン CSS を作成・検証・配置する
argument-hint: "[デザイン名] [コンセプト・基調色などの要望]"
---

`add-design-html` スキルを呼び出して、Markdown → HTML / PDF 変換用の新しいデザインを追加してください。

引数: $ARGUMENTS

## 実行手順

1. **引数の解釈**
   - 第1引数: デザイン名（kebab-case。省略時は対話で確定）
   - 以降: デザインコンセプト・基調色などの要望（自由記述）
2. **Skill ツール経由で実行**

   ```
   Skill(skill: "add-design-html", args: "<デザイン名> <要望...>")
   ```

3. スキル内で CSS 生成 → 契約検証（`validate_css.py`）→ サンプル変換 → 配置が行われる
4. 完了後、配置先の絶対パスと `convert-html` / `convert-pdf` での使い方をユーザーに報告する

## 注意

- HTML 構造は原則デフォルト共通（CSS のみ差し替え）。構造変更が必要なデザインは JS 契約検証付きの同名 HTML ペアとして生成される
- 検証 PASS とサンプル変換成功を確認するまで配置されない
