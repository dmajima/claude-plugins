# Case 01: 単体エージェント新規作成

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "コード品質評価用のエージェント `code-quality-reviewer` を作って" |
| 引数 | `code-quality-reviewer --domain "code-quality"` |
| フラグ | なし |
| 既存状態 | 同名エージェント未存在 |

## 期待動作

### Phase 1: モード判定

単数の役割指定 → 単体エージェントモード。

### Phase 2: 既存エージェント確認

`~/.claude/agents/code-quality-reviewer.md` 未存在を確認。

### Phase 3: 評価観点設計

コード品質ドメインの主要観点を 3 つ以上提示:

- 正確性
- パフォーマンス
- 可読性
- テスト容易性

ユーザに観点の追加・削除を確認。

### Phase 4: テンプレート展開 + 充填

`${CLAUDE_PLUGIN_ROOT}/references/templates/agent/agent.md` をコピー、専門性セクションにデファクトスタンダード（Clean Code、SOLID）を反映。

### Phase 5: 検証 + 引き渡し

通常検証チェックリスト合格後、生成ファイルパス提示。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `{配置先}/code-quality-reviewer.md` |
| 標準出力 | 「`code-quality-reviewer` エージェント作成」+ 利用例 |
| 終了状態 | 成功 |

## 分岐の根拠

単数の役割指定・「チーム」発話なし である。
