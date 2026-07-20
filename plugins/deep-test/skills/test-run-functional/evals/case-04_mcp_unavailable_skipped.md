# case-04 MCP ツール不可 → skipped（二重防御）

Playwright MCP ツールが現セッションでロードされていない（または実行中に喪失した）ケース。実行を偽装せず scope 全ケース（または以降の未実行ケース）を skipped + reason で返すことを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-web / run_id=R20260717-153000 / 対象ケース TC-FUNC-001〜002 / 対象 URL https://localhost:5001 |
| 起動形態 | 委譲（オーケストレータ test から Skill ツール経由） |
| 前提 | `mcp__playwright__*` ツールが未ロード（MCP ゲートの判定漏れ・run 中のセッション喪失・直接起動などの理由）。ブラウザ操作を一切実行できない |

## 分岐の根拠

SKILL.md「実行フロー」手順 2（MCP 二重防御）・「責務外」（MCP ゲート判定はオーケストレータ）・「重要な制約」（偽装禁止）、references/functional-execution.md 5 章（分岐表: MCP 未ロード → skipped）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 2 章（run 中の喪失: 以降の未実行ケースを skipped + reason）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` 4 章（登録済みに見えてもロード済みとは限らない・未検出時は偽装せず skipped で返却）。

## 期待動作

- 初回ブラウザ操作前に MCP ツールの実利用可否を確認する（登録の有無だけで利用可と判定しない）
- 未ロードを検出したら、ブラウザ操作の実行を試みたと装わず、scope 全ケースを **skipped** として返却する（run 途中で喪失した場合は、実行済みケースの結果は保持し、以降の未実行ケースを skipped とする）
- 各 skipped エントリの reason に実際の原因（例: 「Playwright MCP ツール未ロードのためブラウザ操作不能」）を記録する
- skipped を「問題なし」「テスト成功」と書き換えない
- MCP の登録・再起動ハンドオフを自スキルで実施しない（test-setup / オーケストレータの責務。必要性の指摘は返却メッセージで行ってよい）
- scope 全件について 1 エントリずつ返却し、中間結果 JSON を返す

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（MCP 未ロードでブラウザ操作を実行しないため、エビデンスは発生しない）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-functional" / 受領 run_id / results 2 件・各エントリに「Playwright MCP ツール未ロード」等の実原因を記した reason 付き）を 1 コードブロックで返却。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 2 件（TC-FUNC-001〜002）を 1 エントリずつ skipped で返却（run 途中喪失時は実行済み分の結果を保持し以降を skipped。偽装・成功への書き換えなし） |

## 関連ケース

- case-01: MCP 利用可（正常系）
- case-03: 対象 URL 不達タイムアウト（blocked との使い分け）
