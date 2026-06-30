# Case 11: サブエージェント呼び出しによる PR 情報取得（Agent + ファイル受け渡し）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 他プラグイン（code-review）が `Agent()` ツールで起動。プロンプトに `Skill(skill: "connector:azure", args: "読み取りのみ。PR URL: https://tfs.example.com/.../pullrequest/123 の PR メタ情報を取得して")` + ファイル書き出し指示 + マニフェスト返却指示を含む |
| 引数 | PR URL + 出力ディレクトリ `.claude/.local/work/{session}/workspace/connector/` |
| フラグ | なし |
| 既存状態 | credentials.json に `tfs-password` 登録済み。呼び出し元は後続フローで PR diff 取得・レビュー実施を予定 |

## 期待動作

1. サブエージェント内で `Skill(skill: "connector:azure")` を実行
2. azure スキルがパターン B（読み取り）として PR メタ情報を取得
3. 取得結果を `{output-dir}/pr-meta.json` に Write
4. **Skill() の結果報告後もターンを終了せず**、ファイル書き出しとマニフェスト返却を続行
5. マニフェスト JSON のみを返却: `{"status":"success","outputDir":"...","files":{"pr-meta":"pr-meta.json"},"summary":"..."}`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `{output-dir}/pr-meta.json` |
| 返却値 | JSON マニフェスト（status=success） |
| 終了状態 | 成功。呼び出し元のフローが続行可能 |

## 分岐の根拠

subagent-protocol.md セクション 5.1 のテンプレートに基づく Agent() 経由呼び出し。Skill() 直接呼び出し（case-10 等）との違いは、結果がファイル出力 + マニフェスト返却される点と、呼び出し元のフローが停止しない点。

## 関連ケース

- `case-10_delegation_read_pipelines.md`（Skill() 直接の読み取り委譲。フロー停止あり）
- `case-08_delegation_inline_comment.md`（Skill() 直接の書き込み委譲）
