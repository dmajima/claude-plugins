# Case 11: A-Sec フェイルクローズ（Unicode エスケープ / forbidden_key / 終端未検出）

## 入力（複合）

### Sub-case 11-A: enabledPlugins キーが Unicode エスケープで難読化

`settings.json` 内に `"enabledPlugins": [...]` のような Unicode エスケープを含む JSON が存在する。

### Sub-case 11-B: enabledPlugins ブロック内に forbidden_key が混入

A-Sec 第四手順のホワイトリスト（`enabledPlugins` の値部分）に対する検査で、
内部に `"env"` / `"hooks"` / `"command"` 等のホワイトリスト外キーが現れる構造を持つ
settings.json。

### Sub-case 11-C: 500 行内で enabledPlugins ブロック終端が検出できない

`settings.json` が極端に大きく、`enabledPlugins` の `}` 終端が 500 行以内に
出現しない（巨大な内部配列 / 二重ネスト過多）。

### Sub-case 11-D: 倍々再 Grep 後も 4000 行を超えて終端未検出

phase-flow.md A-Sec の倍々再 Grep ループ（500 → 1000 → 2000 → 4000 行）でも
終端を検出できない壊れた構造の settings.json。

## 期待動作（共通）

### Phase A-0-1 / A-0-2: 通常通り

### Phase A: 対象収集の Pre 段階（A-Sec 適用）
- Grep でブロック範囲を解析
- 各 sub-case の検出条件を満たした時点で **fail-closed エラー終了**
- メインコンテキストに settings.json の機密情報は載らない
- `references/output-formats.md` の「エラーメッセージ集約 → A-Sec 失敗」セクションの SSOT フォーマットでエラー出力

### Phase A〜G: 実行されない
- 変更系 CLI 呼び出しなし
- exit ≠ 0 で終了

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更系 CLI 呼び出し | なし |
| 標準出力 | sub-case ごとのエラー識別子（`A-Sec/unicode-escape`、`A-Sec/forbidden-key`、`A-Sec/terminator-not-found`、`A-Sec/max-rerange-exceeded` 等） |
| settings.json 機密情報 | メインコンテキストに一切露出しない |
| 終了状態 | エラー終了（exit ≠ 0） |

## 分岐の根拠

各 sub-case が分岐するトリガー:

- A: `enabledPlugins` キー名に Unicode エスケープが含まれる
- B: 当該ブロック内に `references/cross-cutting-rules.md` 等で定義された
  forbidden key（`env` / `hooks` / `command` 等）が出現
- C: 500 行内で `}` / `]` カウンタが平衡に達しない
- D: 倍々再 Grep の 4000 行上限を超えても平衡に達しない

## 設計意図

A-Sec は plugin-updater の最重要セキュリティ制御であり、正常系ケース（case-10）だけでは
**フェイルクローズ自体が壊れていることに気づけない**。本ケースは各分岐が正常に
ブロックを発火することを回帰テストとして固定する。

## 関連ケース

- `case-10_a_sec_secret_isolation.md`（A-Sec 正常系）
- `references/cross-cutting-rules.md` A-Sec 詳細仕様
