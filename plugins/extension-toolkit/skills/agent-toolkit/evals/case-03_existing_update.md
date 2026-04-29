# Case 03: 既存エージェント改修

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`security-engineer` エージェントに WCAG 観点を追加" |
| 引数 | `security-engineer --add-criteria "WCAG accessibility"` |
| フラグ | なし |
| 既存状態 | `security-engineer.md` 既存 |

## 期待動作

### Phase 1: 既存定義読込

`~/.claude/agents/security-engineer.md` を Read。

### Phase 2: 適合性判定

WCAG 観点は本来 `ux-designer` の領域であることを認識し、ユーザに以下を提示:

```text
WCAG はアクセシビリティ観点であり、`security-engineer` の専門領域（OWASP / CWE / STRIDE）とは異なります。

推奨:
1. `ux-designer` エージェントに WCAG 観点を追加（推奨）
2. それでも `security-engineer` に追加する（理由を明記）
3. キャンセル
```

### Phase 3: 選択分岐

| 選択 | 動作 |
|-----|------|
| 1 | `ux-designer.md` を改修 |
| 2 | `security-engineer.md` に追加（理由をコメントで残す） |
| 3 | 何もしない |

### Phase 4: 検証 + 引き渡し

エンコーディング維持、専門性の相補性を再確認。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | 選択により異なる |
| 標準出力 | 専門性適合性の警告 + 選択結果 |
| 終了状態 | 選択により異なる |

## 分岐の根拠

同名エージェント既存 + 専門領域不一致の検出 である。
