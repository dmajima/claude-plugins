# Case 04: settings.json からフック抽出してプラグイン化

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`settings.json` の Bash ログ用 PreToolUse フックを `dev-toolkit` プラグインに切り出し" |
| 引数 | `dev-toolkit --extract-hook PreToolUse:Bash` |
| フラグ | なし |
| 既存状態 | `dev-toolkit` 既存、`~/.claude/settings.json` に該当 PreToolUse フックあり |

## 期待動作

### Phase 1: settings.json 読込

`<repo>/.claude/settings.json` および `~/.claude/settings.json` を Read。両方に該当エントリがある場合は対話で選択。

### Phase 2: 抽出対象確認

ユーザに具体的な抽出対象（イベント名 + matcher）を確認。

### Phase 3: 抽出 + 書き出し

| ステップ | 動作 |
|---------|------|
| 1 | 該当 hooks エントリを抜き出す |
| 2 | エントリ内のコマンドが `${CLAUDE_PLUGIN_ROOT}` を使うように書き換え |
| 3 | `plugins/dev-toolkit/hooks/hooks.json` に Write |

### Phase 4: 元 settings.json の不変性確認

元 `settings.json` を **絶対に変更しない**。プラグイン化後に元を残すかはユーザ判断（このスキルでは関与しない）。

### Phase 5: 検証

- `hooks.json` valid
- 抽出したフックが正しい構造（matcher / type / command / timeout）
- パスポータビリティ合格

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `plugins/dev-toolkit/hooks/hooks.json`（新規 or 既存に追記） |
| 標準出力（要約） | 「PreToolUse:Bash フックを `dev-toolkit` に抽出」+ 元 `settings.json` の扱いについての案内 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは `--extract-hook` 引数（フック種別の移管） である。
