# Case 18: PreToolUse hook — WebFetch 呼び出し → trigger

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) | `{"tool_name":"WebFetch","tool_input":{"url":"https://api.openai.com/v1/models","prompt":"get models"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `preempt_credentials_check.sh` が `tool_name` を抽出 → `WebFetch`
- `WebFetch | WebSearch` 分岐に該当 → 常に対象

### Phase 2: Claude へ通知

- `additionalContext` で「`[credentials-manager] 外部 URL アクセスツール (WebFetch) の呼び出し。credentials-reader を最優先起動して保存済み認証情報を照合してください (ホストが確定する一致1件->自動適用 / 複数件・ホストが確定しない一致->確認 / 0件->保有有無確認)。`」に続けて、認証情報パターンをマスクして扱うこと・書き込み (保存・編集・削除) は `credentials-manager` に引き継ぐことを通知

### Phase 3: Claude の動作

- 通知を受けて **`credentials-reader`** スキルを最優先で起動
- 対象 URL `https://api.openai.com/...` のドメインで自動マッチ
- マッチ件数に応じた挙動（reader case-01 / case-02 / case-03 と同じ）
- 0 件マッチで保存承諾された場合のみ `credentials-manager` に引き継ぎ

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 有効な JSON（`additionalContext` 含む） |
| 終了コード | 0 |

## 分岐の根拠

`WebFetch` ツールは常に trigger する（最も高頻度な発火点）。通知が起動を指示するのは参照特化の `credentials-reader` で、
書き込みが必要な場合だけ `credentials-manager` に引き継ぐ（フック起動時に読み込むコンテキストを小さくするため）。

## 関連ケース

- `credentials-reader:case-01_auto_match_single.md`（trigger 後の URL 自動マッチ）
- `case-22_pretooluse_read_env_example_noop.md`（同じ常時 trigger カテゴリで no-op 境界）
