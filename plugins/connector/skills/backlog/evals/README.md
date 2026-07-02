# Evals: backlog

このディレクトリは `backlog` スキルの動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| case-01 | 課題取得 + コメント取得（認証確認 OK → API 呼び出し → 整形報告） | 操作種別 = 読み取り（Step 3 経路） |
| case-02 | キーワード + プロジェクト指定の課題検索（プロジェクトキー → projectId 数値解決を経由） | 検索系操作（`projectId[]` が数値 ID 必須） |
| case-03 | コメント投稿（textFormattingRule 取得 → render-check PASS → 承認 → POST → コメント URL 報告） | 操作種別 = 書き込み（本文あり） |
| case-04 | ステータス変更（ステータス名 → statusId 解決 → 変更前後の提示 → 承認 → PATCH） | 書き込み（メタ情報のみ・ID 解決必要・render-check 不要） |
| case-05 | 対象スペースの認証情報が credentials.json にない（API を呼ばず準備依頼して停止） | 認証事前確認（Step 1） = 失敗 |
| case-06 | render-check FAIL（Backlog 記法に Markdown 見出し混入）→ 修正採用 → 再チェック PASS → 投稿 | render-check 総合判定 = FAIL |
| case-07 | コメント投稿の承認でユーザーが「中止」を選択（render-check PASS 済みでも POST を発行せず終了） | AskUserQuestion の選択 = 中止 |
| case-08 | 課題取得で HTTP 401 を受領（リトライせず即停止し、API キーの有効性確認を案内） | HTTP ステータス = 401（リトライ厳禁・即停止） |
| case-09 | 他プラグイン委譲による課題取得（パターン B・読み取りのみ・`Skill()` 経由） | 委譲パターン B（読み取り専用） |
| case-10 | ダイレクトパス URL によるフォルダ内共有ファイル一覧取得 | URL `/file/` 検出 → 共有ファイル一覧取得（Step 3 経路） |
| case-11 | エイリアス URL からのファイル情報取得（エイリアス解決成功パス） | URL `/alias/file/` 検出 → リダイレクト解決 → ダイレクトパスとして API 呼び出し |

## 実行確認方法

各ケースの「入力」セクションのフレーズで Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。

- 各ケースは外部 API（Backlog REST API v2）への実アクセスを前提とするため、`run_evals.py` による自動実行の対象外とする（runnable フロントマターなし）
- 書き込み系ケース（case-03 / 04 / 06）の確認は、検証用スペース・検証用課題に対して行うこと
- AskUserQuestion の実発火・承認 UX は機械検証の射程外のため、人間レビューで確認する

## demo.sh（構造検証）

`demo.sh` は外部 API を一切呼ばない読み取り専用の構造検証スクリプト。SKILL.md の存在・frontmatter（`name: backlog`）・参照 references ファイルの存在・evals ケースファイルの存在を確認する。

```bash
# 計画のみ表示（副作用ゼロ; 既定）
bash demo.sh

# 検証を実行（読み取り専用チェックのみ）
bash demo.sh --no-whatif
```
