# Evals: google-workspace

このディレクトリは `google-workspace` スキルの動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| case-01 | ファイル検索（キーワード指定 → search_files → 結果一覧報告） | 正常系 — 読み取り操作 |
| case-02 | ドキュメント読取（ファイル ID 指定 → read_file_content → 内容報告） | 正常系 — 読み取り操作 |
| case-03 | ファイル作成（作成内容確認 → 承認 UI → create_file → 作成完了報告） | 正常系 — 書き込み操作（承認必須） |
| case-04 | 最近のファイル一覧（list_recent_files → 一覧報告） | 正常系 — 読み取り操作 |
| case-05 | Google Drive MCP サーバー未接続（MCP ツール利用不可 → フォールバック案内） | エラー系 — MCP 利用不可 |
| case-06 | ファイル作成の承認でユーザーが「中止」を選択（作成を実行せず終了） | 異常系 — AskUserQuestion の選択 = 中止 |

## 実行確認方法

各ケースの「入力」セクションのフレーズで Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。

- 各ケースは MCP ツール（mcp__claude_ai_Google_Drive__*）への実アクセスを前提とするため、`run_evals.py` による自動実行の対象外とする（runnable フロントマターなし）
- 書き込み系ケース（case-03）の確認は、検証用フォルダに対して行うこと
- AskUserQuestion の実発火・承認 UX は機械検証の射程外のため、人間レビューで確認する

## demo.sh（構造検証）

`demo.sh` は外部 API を一切呼ばない読み取り専用の構造検証スクリプト。SKILL.md の存在・frontmatter（`name: google-workspace`）・参照 references ファイルの存在・evals ケースファイルの存在を確認する。

```bash
# 計画のみ表示（副作用ゼロ; 既定）
bash demo.sh

# 検証を実行（読み取り専用チェックのみ）
bash demo.sh --no-whatif
```
