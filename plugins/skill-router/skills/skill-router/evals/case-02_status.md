# case-02 status

skill-router スキルが `router の状態を確認したい` 系の依頼に対し、`/router-status` を案内する正例。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "router の状態を確認したい" |
| 既存状態 | `<base>/index.json` 生成済 / `sessions/` 配下に最低 1 セッション分の `route_decisions.jsonl` 存在 |
| モード | 対話 |

## トリガープロンプト

```text
router の状態を確認したい
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | skill-router スキルが起動する（high 帯） |
| 2 | base ディレクトリ解決順位（`${CLAUDE_PLUGIN_DATA}` → `<repo>/.claude/.local/...` → `${HOME}/.claude/.local/...`）に従い `<base>` を特定 |
| 3 | `<base>/index.json` / `inverted_index.json` を Read し統計を整形 |
| 4 | `<base>/sessions/*/route_decisions.jsonl` の最終 10 件を tail し tier 別集計 |
| 5 | `--clean` オプションの存在を補足説明 |

## 期待出力

| 出力 | 内容 |
|-----|------|
| 標準出力 | `total_skills_indexed`, `skills_with_evals`, `scan_duration_ms`, 逆引きキーワード数, `overgeneric` 件数, 直近決定の tier 集計, スコア分布ヒストグラム |
| 副作用 | なし（`--clean` 未指定時） |
| disabled フラグ存在時 | 「現在 OFF（フラグ位置: <path>）」を併記 |

## 分岐の根拠

`commands/router-status.md` と `references/scripts/lib/build_index.py` の `stats` 構造に基づく監視・診断のエントリポイント。チューニング時に `config.json` 編集と組み合わせて使う。

## 関連ケース

- `case-01_rebuild` — `/router-rebuild` 後の状態確認（generated_at が新しいかを観測）
- `case-03_disable` — disabled フラグ存在時の status 表示（OFF 表示確認）

## 備考

- 同義表現として「router の statistics」「skill-router 統計」「ルーティング履歴を見たい」等もカバー
- `--clean` オプション（30 日超セッション削除）の存在も合わせて案内できると望ましい
