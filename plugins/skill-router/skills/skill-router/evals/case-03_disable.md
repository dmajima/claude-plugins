# case-03 disable

skill-router スキルが `skill-router を一時停止して` 系の依頼に対し、`/router-toggle off` を案内する正例。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "skill-router を一時停止して" |
| 既存状態 | プラグイン有効化済 / `disabled` フラグ不在（無効化前の状態） |
| モード | 対話 |

## トリガープロンプト

```text
skill-router を一時停止して
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | skill-router スキルが起動する（high 帯） |
| 2 | `/router-toggle off` を案内、または直接実行 |
| 3 | 書き込み先（解決順位 1 番目の `<base>`）を選定し `disabled` ファイルを `touch` |
| 4 | 切替後の状態（OFF）と作成したフラグパスをユーザに提示 |

## 期待出力

| 出力 | 内容 |
|-----|------|
| 標準出力 | `skill-router toggled OFF (flag: <base>/disabled)` |
| 副作用 | `<base>/disabled` ファイル作成 |
| 補足案内 | 再有効化方法（`/router-toggle on` または `disabled` 削除） + 3 段階フラグ参照位置の明示 |

## 分岐の根拠

`commands/router-toggle.md` と `references/scripts/hooks/route_prompt.sh` のトグル参照順位に基づく即時無効化機構。`route_prompt.sh` の base 解決順位と一致しており、Claude Code 再起動なしで反映される。

## 関連ケース

- `case-08_toggle_on` — 再有効化（`/router-toggle on`）分岐
- `case-02_status` — disabled フラグ存在時の status 表示（OFF 表示確認）

## 備考

- 同義表現として「ルーティングを切って」「router を無効化」「skill-router off」等もカバー
- 再有効化（`/router-toggle on`、または `disabled` ファイル削除）の案内も合わせると良い
- べき等動作: 既存フラグへの再 touch は影響なし
