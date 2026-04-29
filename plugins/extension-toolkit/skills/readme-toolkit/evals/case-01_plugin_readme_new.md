# Case 01: プラグイン README 新規作成

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`dev-toolkit` プラグインの README を書いて" |
| 引数 | `--plugin dev-toolkit` |
| フラグ | なし |
| 既存状態 | `plugins/dev-toolkit/.claude-plugin/plugin.json` 既存、`README.md` 未存在 |

## 期待動作

### Phase 1: 対象種別判定

`plugin-name` 形式の引数 → プラグイン対象。

### Phase 2: 既存内容のスキャン

| スキャン対象 | 抽出内容 |
|------------|---------|
| `plugin.json` | name / description / author |
| `commands/` | コマンド一覧 |
| `skills/` | スキル一覧（各 SKILL.md の name + description 抜粋） |
| `agents/` | エージェント一覧 |
| `hooks/hooks.json` | フック設定の有無 |

### Phase 3: テンプレート展開 + 充填

`templates/readme/README.md` をベースに、スキャン結果を反映。

### Phase 4: 検証 + 引き渡し

過去履歴記載なし、ファイル構成が実構成と一致。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `plugins/dev-toolkit/README.md` |
| 標準出力 | 「`dev-toolkit` プラグインの README 作成」+ 内容サマリ |
| 終了状態 | 成功 |

## 分岐の根拠

`--plugin` 引数 + README 未存在 である。
