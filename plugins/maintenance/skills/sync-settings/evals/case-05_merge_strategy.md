# Case 05: merge 戦略で settings.json をマージ

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "マージ戦略で同期して（既存設定を保持しつつリモート分を取り込む）" |
| 引数 | `--strategy merge` |
| フラグ | なし |
| 既存状態 | ローカル `settings.json` に独自キー（env / hooks 追加等）、リモート `settings.json` に新規キー |

## 期待動作

### Phase 1〜4: 設定解決〜差分検出
- 通常通り

### Phase 5: AskUserQuestion 確認
- 戦略 merge で確認
- ユーザが「同期する」を選択

### Phase 6: バックアップ取得
- 必須実施

### Phase 7: 同期適用（merge）
| 対象 | 動作 |
|-----|------|
| `settings.json` | 深い JSON マージ。ローカル独自キーは保持、リモートの新規キーは追加、両方にあるキーはリモートで上書き |
| `skills/`、`rules/` 等のディレクトリ | ファイル単位で結合。同名ファイルはリモートで上書き、ローカルのみのファイルは保持 |
| 配列（settings.json 内の配列値） | リモート値で置換（連結ではない） |

### Phase 8: 設定保存
- `last_strategy = "merge"` で記録

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | バックアップ + 更新された `~/.claude/settings.json`（マージ結果） |
| 標準出力（要約） | 「戦略: merge」「適用件数: N 件」 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは `--strategy merge` 指定である。

## 重要な動作

- ローカルに `env.MY_CUSTOM_VAR=value` があり、リモートに同キーがない場合 → 保持される
- ローカルに `permissions.allow: ["foo"]` があり、リモートに `permissions.allow: ["bar", "baz"]` がある場合 → リモート値 `["bar", "baz"]` で置換（配列マージは行わない）
- リモートに `hooks.PostCommit` の新規定義がある場合 → 追加される

## 関連ケース

- `case-02_interactive_overwrite.md`（上書き戦略との比較）
- `case-06_skip_strategy.md`（スキップ戦略との比較）
