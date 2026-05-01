# Case 13: `.gitignore` 未登録時の警告

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "API キー `xyz-secret-9876543210` を test-key として保存して。" |
| 引数 | name=test-key, value=xyz-secret-9876543210 |
| フラグ | なし（対話モード） |
| 既存状態 | リポジトリ内（祖先に `.git` あり）。`.gitignore` に `.claude/.local/` が未登録。`credentials.json` 不在 |

## 期待動作

### Phase 1: パス解決

- 祖先で `.git` を発見し project-scoped パスを解決

### Phase 2: `.gitignore` 確認

- リポジトリルートの `.gitignore` を読み、`.claude/.local/` または `.claude/` が未登録であることを検出

### Phase 3: ユーザ警告と確認

- `AskUserQuestion` で以下を提示:
  - 「`.gitignore` に `.claude/.local/` が登録されていません。`credentials.json` がコミットされる恐れがあります」
  - 選択肢:
    - 「`.gitignore` に `.claude/.local/` を追加してから保存する」（推奨）
    - 「警告を承知の上で保存する」
    - 「キャンセル」

### Phase 4: 選択別の動作

- 「追加してから保存」 → `.gitignore` 末尾に `.claude/.local/` を追記、その後保存実行
- 「承知の上で保存」 → `.gitignore` を変更せず保存
- 「キャンセル」 → 何も書かずに終了

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | 選択に応じて `.gitignore`（更新）+ `credentials.json`、または変更なし |
| 標準出力（要約） | 警告メッセージ + 確認質問 + ユーザ選択後の動作結果 |
| 終了状態 | ユーザ選択に応じる |

## 分岐の根拠

このケースは「パス解決・優先順位 1（リポジトリ内）+ `.gitignore` 未登録」分岐に該当する。`credentials.json` のコミット混入防止が主要な検証観点。

## 関連ケース

- `case-01_save_with_url.md`（`.gitignore` 登録済み時の通常フロー）
- `case-12_user_scoped_save.md`（リポジトリ外で `.gitignore` 検査が不要な対比）
