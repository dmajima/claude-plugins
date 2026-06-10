# Case 03: 出席者欄の並び順・敬称・bot 除外

## 入力

| 項目 | 値 |
|-----|---|
| 起動条件 | case-01 と同一（正常な Markdown 生成） |
| 前提ファイル | `workspace/minutes.json` の `metadata.participants` に顧客・自社・bot が混在 |

`metadata.participants` の例（配列順は ailead レスポンス順 = 自社が先頭）:

```json
[
  {"name": "眞嶋大介", "organization": "Ｗ２株式会社", "role": "host"},
  {"name": "阿部優生", "organization": "Ｗ２株式会社", "role": "participant"},
  {"name": "山根 良太", "organization": "日世株式会社", "role": "participant"},
  {"name": "亀岡 大輝", "organization": "日世株式会社", "role": "participant"},
  {"name": "Rimo議事録Bot", "organization": "Rimo", "role": "bot"}
]
```

## 期待動作

1. `generate_md.py` の `arrange_participants()` が出席者欄の表示行を組み立てる
2. 並び順: 顧客組織（participants の出現順を維持）→ 組織不明 → 自社組織（`role == "host"` の参加者が属する組織）
3. 敬称: 顧客のみ「会社名 / 氏名 様」（氏名と「様」の間に半角スペース）。自社・組織不明は様なし
4. `role == "bot"` の参加者は出席者欄に出力しない
5. 各行に `- ` プレフィックスを付与する（Markdown 箇条書き）

## 期待出力

Markdown の出席者セクションが以下の順・形式になる:

```markdown
出席者:
- 日世株式会社 / 山根 良太 様
- 日世株式会社 / 亀岡 大輝 様
- Ｗ２株式会社 / 眞嶋大介
- Ｗ２株式会社 / 阿部優生
```

| 検証観点 | 期待値 |
|---------|-------|
| 並び順 | 顧客が先・自社（host 組織）が最後 |
| 敬称 | 顧客のみ「 様」（半角スペース + 様）、自社は様なし |
| bot | 出席者欄に出力されない |
| 組織不明（`organization` が空） | 氏名のみ・様なしで顧客と自社の間に配置 |

## 分岐の根拠

`minutes-composer/references/schema/minutes-schema.md`「participants の role 設定」: 表示順・敬称・bot 除外はレンダラーが決定する。`minutes-docx` の case-06 と同一観点（両レンダラーで仕様を揃える）。

## 関連ケース

- `case-01_normal.md`（正常生成の基本フロー）
- `minutes-docx/evals/case-06_participants_order.md`（docx 側の同一観点ケース）
