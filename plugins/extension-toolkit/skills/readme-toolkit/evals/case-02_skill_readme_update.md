# Case 02: スキル README 更新

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`code-formatter` スキルの README を最新化" |
| 引数 | `--skill code-formatter` |
| フラグ | なし |
| 既存状態 | `skills/code-formatter/SKILL.md` 既存、`README.md` 既存（古い） |

## 期待動作

### Phase 1: 対象種別判定

`--skill` 引数 → スキル対象。

### Phase 2: 既存内容のスキャン

`SKILL.md` のトリガー条件・責務・関連スキルを抽出。`references/` のファイル一覧を取得。

### Phase 3: 既存 README との差分比較

提供機能・関連スキル・参照ファイルが現状と一致するか確認。差分があれば更新内容を整理。

### Phase 4: 更新書き出し

エンコーディング・改行コードを維持して書き戻す。過去履歴記載があれば除去。

### Phase 5: 検証 + 引き渡し

通常検証。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `skills/code-formatter/README.md` |
| 標準出力 | 「`code-formatter` README 更新」+ 差分サマリ |
| 終了状態 | 成功 |

## 分岐の根拠

`--skill` 引数 + README 既存 である。
