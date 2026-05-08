# Case 08: 非対話モードでの自動マッチ（複数件ヒット、最新採用）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "--non-interactive で https://api.openai.com/v1/models を呼び出して。" |
| 引数 | URL あり |
| フラグ | `--non-interactive` 相当 |
| 既存状態 | `credentials.json` に同ドメインの認証情報が複数件存在（updated_at に差あり） |

## 期待動作

### Phase 1: 暗黙トリガー発火 + 非対話モード判定

- URL アクセス依頼を検出 → `credentials-reader` 起動
- 非対話モードと判定（フラグ・引数明示）

### Phase 2: マッチング + 自動採用

- 複数件ヒット
- `AskUserQuestion` を起動せず、最新 `updated_at` のエントリを採用

### Phase 3: 自動適用 + API 呼び出し

- 採用した認証情報を付けて API 呼び出し
- 通知: "Auto-selected '<latest-name>' (<masked>) for api.openai.com (non-interactive mode)."

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし |
| 標準出力（要約） | 自動採用通知 + API レスポンス |
| 終了状態 | 成功 |

## 分岐の根拠

「非対話モード + 複数件マッチ」分岐。対話モードと異なり `AskUserQuestion` を発火せず、最新更新を既定値として進行することを検証する。

## 関連ケース

- `case-02_auto_match_multiple.md`（対話モードでの選択依頼）
