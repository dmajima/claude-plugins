# Case 02: レビューチーム編成（4 名）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "コードレビューチームを編成。実装品質・テスト・セキュリティ・アーキテクチャの 4 観点で" |
| 引数 | `--team code-review --members "implementation-engineer,test-engineer,security-engineer,architect" --lead architect` |
| フラグ | `--team` |
| 既存状態 | 各メンバーのエージェント定義は `~/.claude/agents/` に既存 |

## 期待動作

### Phase 1: モード判定

`--team` フラグあり → チームモード。

### Phase 2: メンバー存在確認

各メンバーのエージェント定義が `~/.claude/agents/` に存在することを確認。

### Phase 3: 必要観点の網羅性検証

| 観点 | 担当 |
|-----|------|
| 実装品質 | `implementation-engineer` |
| テスト | `test-engineer` |
| セキュリティ | `security-engineer` |
| アーキテクチャ | `architect`（リード） |

[`../references/team-design.md`](../references/team-design.md) の「コードレビュー」観点と一致を確認。

### Phase 4: テンプレート展開

`templates/agent/team.md` を配置先にコピー、プレースホルダ置換。

### Phase 5: スポーンプロンプト充填

各メンバーの責務、議論ラウンド 3 回、期待成果物を反映。

### Phase 6: 検証 + 引き渡し

チーム検証チェックリスト合格を確認。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `~/.claude/teams/code-review.md` または プラグイン内 `teams/code-review.md` |
| 標準出力 | 「`code-review` チーム編成（4 名）」+ スポーンプロンプト例 |
| 終了状態 | 成功 |

## 分岐の根拠

`--team` フラグ + メンバー数 4 名（最低 3 名） である。
