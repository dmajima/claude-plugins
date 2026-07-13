# Evals: azure

このディレクトリは `azure` スキルの動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| case-01 | オンプレ TFS への PR 作成（ホスト判定 TFS → ブランチ・重複確認 → render-check → 承認 → POST → PR URL 報告） | ホスト種別 = TFS（curl --ntlm / api-version 6.0）+ 操作 = PR 作成 |
| case-02 | クラウド PR へのコメント投稿（az devops invoke / api-version 7.1。render-check → 承認 → 投稿） | ホスト種別 = クラウド（dev.azure.com → az CLI） |
| case-03 | PR 承認（vote=10。connectionData で自分の reviewer ID を取得 → PUT） | 操作種別 = 書き込み（本文なし）= render-check 省略・vote 値明示の承認必須 |
| case-04 | TFS 作業項目へのコメント投稿（render-check FAIL → HTML 変換 → JSON Patch で System.History に add） | 投稿先 = TFS 作業項目（System.History は Markdown 非解釈・HTML レンダリング） |
| case-05 | 未登録ホストへの操作依頼（API を発行せずユーザー確認 → 対話取得フォールバックで登録・続行、中止時のみ終了） | ホスト判定 = 4（クラウドにも登録済み TFS にも該当しない） |
| case-06 | TFS PR コメント投稿の承認でユーザーが「中止」を選択（threads API を発行せず中止を報告） | AskUserQuestion の選択 = 中止 |
| case-07 | TFS PR へのインラインコメント投稿（threadContext 付き。パターン A・全安全ゲート通過） | 操作種別 = インラインコメント（threadContext 付きスレッド作成） |
| case-08 | 他プラグイン委譲によるインラインコメント投稿（パターン B。render-check・承認スキップ） | 呼び出しパターン = B（委譲）+ 本文あり書き込み |
| case-09 | 他プラグイン委譲によるスレッドステータス変更（パターン B。承認スキップ） | 呼び出しパターン = B（委譲）+ 本文なし書き込み |
| case-10 | 他プラグイン委譲による Pipelines ビルド結果取得（パターン B。読み取り・透過返却） | 呼び出しパターン = B（委譲）+ 読み取り系 |
| case-11 | サブエージェント呼び出しによる PR 情報取得（ファイル書き出し + success マニフェスト返却） | 呼び出し方式 = `Agent()`（subagent-protocol.md）正常系 |
| case-12 | サブエージェント呼び出しで認証情報なし（質問せず `credentials_missing` マニフェスト返却 → 呼び出し元が対話復帰） | 実行コンテキスト = サブエージェント（解決順序 3b） |
| case-13 | パターン A（ユーザー直接）の PR 情報読み取り | 呼び出しパターン = A + 読み取り系 |
| case-14 | 登録済み TFS 資格情報の失効（401。同一値でリトライせず対話取得フォールバックで再取得を確認） | HTTP ステータス = 401（同一値リトライ厳禁・新値受領時のみ 1 回再実行） |

## 実行確認方法

各ケースの「入力」セクションのフレーズで Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。

- 各ケースは外部 API（Azure DevOps / TFS REST API・az CLI）への実アクセスを前提とするため、`run_evals.py` による自動実行の対象外とする（runnable フロントマターなし）
- 書き込み系ケース（case-01 / 02 / 03 / 04）の確認は、検証用プロジェクト・検証用 PR / 作業項目に対して行うこと
- AskUserQuestion の実発火・承認 UX は機械検証の射程外のため、人間レビューで確認する

## demo.sh（構造検証）

`demo.sh` は外部 API を一切呼ばない読み取り専用の構造検証スクリプト。SKILL.md の存在・frontmatter（`name: azure`）・参照 references ファイルの存在・書き込みゲート記述（render-check / AskUserQuestion）の存在・evals ケースファイルの存在を確認する。

```bash
# 計画のみ表示（副作用ゼロ; 既定）
bash demo.sh

# 検証を実行（読み取り専用チェックのみ。ファイル変更・外部通信なし）
bash demo.sh --no-whatif
```
