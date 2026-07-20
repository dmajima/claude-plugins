# case-07 MCP ツール不可 → skipped（IT-a/IT-b 混在 scope・二重防御）

Playwright MCP ツールが現セッションで未ロードのケース。IT-a・IT-b が混在する scope でも、実行を偽装せず全ケースを skipped + reason で返却することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260717-160000` / ケース: `[TC-ITA-001, TC-ITB-001]`（IT-a と IT-b の混在）/ アプリ情報: `https://localhost:5001` / 外部接続先情報あり |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ） |
| 前提 | `mcp__playwright__*` ツールが未ロード（MCP ゲートの判定漏れ・run 中のセッション喪失・直接起動などの理由）。ブラウザ操作を一切実行できない |

## 分岐の根拠

SKILL.md「実行フロー」手順 2（MCP 二重防御: 未ロードなら scope 全ケースを skipped + reason で返却）・「責務外」（MCP ゲート判定はオーケストレータ・本スキルは二重防御確認のみ）・「重要な制約」（実行手段不在時に実行を偽装しない）、`${CLAUDE_SKILL_DIR}/references/integration-execution.md` 6 章（status 判定の分岐: MCP ツール未ロード → skipped + reason）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 2 章（run 中の喪失: 以降の未実行ケースを skipped + reason）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` 4 章（登録済みでもロード済みとは限らない・未検出時は偽装せず skipped 返却）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（skipped と blocked の使い分け）。

## 期待動作

- 初回ブラウザ操作前に `mcp__playwright__*` ツールの実利用可否を確認する（登録の有無だけで利用可と判定しない）
- 未ロードを検出したら、IT-a（画面間遷移フロー）・IT-b（外部 IF 連携）いずれのケースもブラウザ操作を試みず、**scope 全 2 件を skipped** として返却する（run 途中で喪失した場合は実行済みケースの結果を保持し、以降の未実行ケースを skipped とする）
- 各 skipped エントリの reason に実際の原因（例: 「Playwright MCP ツール未ロードのため連携フロー確認不能」）を記録する
- `blocked`（論理ブロック）ではなく `skipped`（実行手段不在）を用いる（yaml-schema-results.md 6 章）
- skipped を「pass」「問題なし」「実接続検証済み」に書き換えない
- MCP の登録・再起動ハンドオフを自スキルで実施しない（test-setup / オーケストレータの責務。必要性の指摘は返却メッセージで行ってよい）
- scope 全件について 1 エントリずつ返却し、中間結果 JSON を返す

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（ブラウザ操作を実行しないためエビデンス生成なし）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-integration" / 受領 run_id / results 2 件すべて skipped + reason）。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 2 件を skipped で返却（IT-a / IT-b とも）。MCP 未整備の指摘を特記事項に添える |

## 関連ケース

- case-01: IT-a 正常実行（MCP 利用可）
- case-02: IT-b 外部接続不可のスタブ判断（実行手段不在の別要因との対比）
- case-08: manual-assist ケースの skipped（非対話時の別要因での skipped）
