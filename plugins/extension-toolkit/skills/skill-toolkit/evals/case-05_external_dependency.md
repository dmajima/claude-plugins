# Case 05: 外部依存スキル参照付きスキル作成

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`example-skills` を参考に PDF 生成スキル `pdf-generator` を作って" |
| 引数 | `pdf-generator --external-deps "document-skills:pdf"` |
| フラグ | `--external-deps` |
| 既存状態 | `pdf-generator` スキル未存在、`document-skills@anthropic-agent-skills` インストール済み |

## 期待動作

### Phase 1: 外部スキル可用性確認

`document-skills:pdf` がユーザ環境で利用可能か確認。

| 状態 | 動作 |
|-----|------|
| インストール済み | そのまま進行 |
| 未インストール | インストール手順を提示し、ユーザに継続意思を確認 |

### Phase 2: テンプレート展開 + 外部依存反映

通常のテンプレート展開後、生成スキルの `SKILL.md` に「依存外部スキル」セクションを追加。

```markdown
## 依存外部スキル

| スキル | マーケットプレイス | 用途 |
|-------|-----------------|------|
| `document-skills:pdf` | anthropic-agent-skills | PDF 生成 |
```

### Phase 3: 利用パターン記述

生成スキル内で `Skill` ツール経由で外部スキルを呼び出す手順を `references/procedures.md` に記述。

### Phase 4: 検証

- 通常チェックに加え、依存外部スキルセクションの存在確認
- 外部スキルの直接スクリプト呼び出しがハードコードされていないこと

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | 通常一式 + 依存スキル参照を含む `SKILL.md` `references/procedures.md` |
| 標準出力（要約） | 「`pdf-generator` スキル作成（`document-skills:pdf` を Skill ツール経由で利用）」+ 利用例 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは `--external-deps` 引数の有無 である。

## 関連ケース

- `case-01_new_skill_interactive.md`（外部依存なし）
- 詳細は [`../references/external-dependencies.md`](../references/external-dependencies.md) を参照
