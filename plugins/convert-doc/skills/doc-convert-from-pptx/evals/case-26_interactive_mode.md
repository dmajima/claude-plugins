# Case 26: 対話モード（AskUserQuestion フロー）

## 入力

- ユーザ発話: 「このPPTXをMarkdownに変換して」（入力ファイルパス未指定）
- `--non-interactive` フラグなし

## 期待動作

1. SKILL.md の「実行モード判定」で「自然言語依頼 → 対話モード」と判定
2. 不足パラメータ（入力 PPTX パス）を `AskUserQuestion` でユーザに確認
3. ユーザ回答後に変換処理（2 フェーズ）を実施
4. 必要に応じて出力先・オプション（`--include-notes` 等）も `AskUserQuestion` で確認
5. 確認完了後は非対話モードと同じフローで変換実行

## 期待出力

- ユーザに以下のような選択肢を提示:
  ```
  入力 PPTX のパスを指定してください
  - 候補 1: <推測パス>
  - 候補 2: <別の候補>
  - Other: 手動入力
  ```
- ユーザ回答に基づいて変換実施
- 最終的に Markdown ファイルを生成

## 分岐の根拠

`SKILL.md` の「実行モード判定」表:
```
| 上記以外（自然言語依頼） | 対話 | 不足パラメータを `AskUserQuestion` でユーザに確認 |
```

グローバルルール `user-interaction.md` の AskUserQuestion 優先原則。

## 関連ケース

- [case-01_normal_with_title.md](case-01_normal_with_title.md): 非対話モードの標準変換
- [case-27_fallback_mode.md](case-27_fallback_mode.md): LLM 介入なしのフォールバック
