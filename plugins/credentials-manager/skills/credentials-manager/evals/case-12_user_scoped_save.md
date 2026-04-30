# Case 12: user-scoped 保存（リポジトリ外）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "OpenAI の API キー `sk-proj-abcdefghij1234567890` を保存して。" |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | 現在のワーキングディレクトリの祖先に `.git` が存在しない（リポジトリ外）。`~/.claude/.local/plugins/credentials-manager/credentials.json` は不在 |

## 期待動作

### Phase 1: パス解決

- 祖先ディレクトリを走査しても `.git` を見つけられない
- フォールバックルールに従い `~/.claude/.local/plugins/credentials-manager/credentials.json` を解決パスに採用
- 親ディレクトリ（`~/.claude/.local/plugins/credentials-manager/`）が無ければ作成

### Phase 2: 識別名・種別の確定

- 識別名 `openai-api-key`（候補提示 → ユーザ確認）
- 種別 `api_key`

### Phase 3: 保存

- 空ストアで初期化したファイルにエントリを追加
- 書き戻し

### Phase 4: 確認通知

- マスク済み値 + 保存先パス + スコープ（user-scoped）を表示

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `~/.claude/.local/plugins/credentials-manager/credentials.json` |
| 標準出力（要約） | "Saved credential 'openai-api-key' (api_key): sk-p****7890 — user-scoped (`~/.claude/.local/plugins/credentials-manager/credentials.json`)" |
| 終了状態 | 成功 |

## 分岐の根拠

このケースは「パス解決・優先順位 2（フォールバック）」分岐に該当する。`.git` 不在環境でユーザースコープに正しく書き込まれることを検証する（プロジェクト単位の汚染がないこと）。

## 関連ケース

- `case-01_save_with_url.md`（project-scoped 保存との対比）
